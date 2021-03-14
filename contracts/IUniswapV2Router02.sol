pragma solidity ^0.6.0;

abstract contract ILendingPool {

	function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        virtual
        override
        returns (uint[] memory amounts);
        
}