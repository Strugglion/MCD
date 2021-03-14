pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import "./IUniswapV2Router02.sol";
import "./ILendingPool.sol";
import "./Manager.sol";
import "./DefisaverLogger.sol";
import "./SafeERC20.sol";
import "./DFSExchangeData.sol";

contract MCDCreateTakerV2 {

    address public constant ETH_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address public constant USDT_ADDRESS = 0xdac17f958d2ee523a2206206994597c13d831ec7;
    address public constant DAI_ADDRESS = 0x6b175474e89094c44da98b954eedeac495271d0f;
    address public constant WETH_ADDRESS = 0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2;
    address public constant NULL_ADDRESS = 0x0000000000000000000000000000000000000000;

	// address public constant DAI_JOIN_ADDRESS = 0x9759A6Ac90977b93B58547b4A71c78317f391A28;
    address public constant ETH_JOIN_ADDRESS = 0x2F0b23f53734252Bda2277357e97e1517d6B042A;

    address public constant UNISWAP_WRAPPER_ADDRESS = 0x6403BD92589F825FfeF6b62177FCe9149947cb9f;

    address payable public constant MCD_CREATE_FLASH_LOAN = 0x409F216aa8034a12135ab6b74Bf6444335004BBd;

    IUniswapV2Router02 public constant uni = IUniswapV2Router02(0x7a250d5630b4cf539739df2c5dacb4c659f2488d);

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
        address[] path = [_collData.collToken, WETH_ADDRESS];
        if (_collData.collToken != ETH_ADDRESS) {
            (, collETHAmount) = uni.swapExactTokensForETH(_collData.collAmount, 0, path, MCD_CREATE_FLASH_LOAN, block.timestamp + 1);
        }

        CreateData createData = CreateData(collETHAmount, _collData.daiAmount, ETH_JOIN_ADDRESS);

        DFSExchangeData.ExchangeData = DFSExchangeData.ExchangeData(DAI_ADDRESS, ETH_ADDRESS, _collData.daiAmount, 0, 0, 0, 
            NULL_ADDRESS, UNISWAP_WRAPPER_ADDRESS, abi.encode(path), 
            [NULL_ADDRESS, NULL_ADDRESS, NULL_ADDRESS, 0, 0, abi.encode('')]);


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
