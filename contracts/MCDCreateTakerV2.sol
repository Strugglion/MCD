// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import "./interfaces/IUniswapV2Router02.sol";
import "./interfaces/ILendingPool.sol";
import "./utils/SafeERC20.sol";
import "./utils/GasBurner.sol";
import "./Manager.sol";
import "./DefisaverLogger.sol";
import "./DFSExchangeData.sol";

contract MCDCreateTakerV2 is GasBurner {

    using SafeERC20 for ERC20;

    address public constant ETH_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address public constant USDT_ADDRESS = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address public constant DAI_ADDRESS = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address public constant WETH_ADDRESS = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant NULL_ADDRESS = 0x0000000000000000000000000000000000000000;

	// address public constant DAI_JOIN_ADDRESS = 0x9759A6Ac90977b93B58547b4A71c78317f391A28;
    address public constant ETH_JOIN_ADDRESS = 0x2F0b23f53734252Bda2277357e97e1517d6B042A;

    address public constant UNISWAP_WRAPPER_ADDRESS = 0x6403BD92589F825FfeF6b62177FCe9149947cb9f;

    address payable public constant MCD_CREATE_FLASH_LOAN = 0x409F216aa8034a12135ab6b74Bf6444335004BBd;

    IUniswapV2Router02 public constant uni = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);

	ILendingPool public constant lendingPool = ILendingPool(0x398eC7346DcD622eDc5ae82352F02bE94C62d119);

    Manager public constant manager = Manager(0x5ef30b9986345249bc32d8928B7ee64DE9435E39);	

    DefisaverLogger public constant logger = DefisaverLogger(0x5c55B921f590a89C1Ebe84dF170E655a82b62126);

    struct CreateData {
        uint collAmount;
        uint daiAmount;
        address joinAddr;
    }

    struct CollData {
        address collToken;
        uint collAmount;
        uint daiAmount;
    }

    function openWithLoanV2 (
        CollData memory _collData
    ) public payable burnGas(20) {

        require (_collData.collToken == ETH_ADDRESS || _collData.collToken == USDT_ADDRESS || _collData.collToken == DAI_ADDRESS, "invalid collateral");        

        MCD_CREATE_FLASH_LOAN.transfer(msg.value); //0x fee

        // 计算抵押的ETH数量（非ETH抵押资产需要通过uniswap转换成ETH）
        uint collETHAmount = _collData.collAmount;
        address[] memory path = new address[](2);
        path[0] = _collData.collToken;
        path[1] = WETH_ADDRESS;
        // address[2] memory path = [_collData.collToken, WETH_ADDRESS];
        if (_collData.collToken != ETH_ADDRESS) {
            ERC20(_collData.collToken).safeTransferFrom(msg.sender, address(this), _collData.collAmount);
            ERC20(_collData.collToken).safeTransfer(MCD_CREATE_FLASH_LOAN, _collData.collAmount);
            // (, collETHAmount) = uni.swapExactTokensForETH(_collData.collAmount, 0, path, MCD_CREATE_FLASH_LOAN, block.timestamp + 1);
            uint[] memory swappedAmounts = uni.swapExactTokensForETH(_collData.collAmount, 0, path, MCD_CREATE_FLASH_LOAN, block.timestamp + 1);
            collETHAmount = swappedAmounts[swappedAmounts.length - 1];
        }

        CreateData memory createData = CreateData(collETHAmount, _collData.daiAmount, ETH_JOIN_ADDRESS);

        DFSExchangeData.ExchangeData memory exchangeData = DFSExchangeData.ExchangeData(DAI_ADDRESS, ETH_ADDRESS, _collData.daiAmount, 
            0, 0, 0, NULL_ADDRESS, UNISWAP_WRAPPER_ADDRESS, abi.encode(path), 
            DFSExchangeData.OffchainData(NULL_ADDRESS, NULL_ADDRESS, NULL_ADDRESS, 0, 0, abi.encode('')));

        bytes memory packedData = _packData(createData, exchangeData);
        bytes memory paramsData = abi.encode(address(this), packedData);

        lendingPool.flashLoan(MCD_CREATE_FLASH_LOAN, DAI_ADDRESS, createData.daiAmount, paramsData);

        logger.Log(address(this), msg.sender, "MCDCreate", abi.encode(manager.last(address(this)), createData.collAmount, createData.daiAmount));
    }

    function _packData (
        CreateData memory _createData,
        DFSExchangeData.ExchangeData memory _exchangeData
    ) internal pure returns (bytes memory) {

        return abi.encode(_createData, _exchangeData);
    }
	
}
