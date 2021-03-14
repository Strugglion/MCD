// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

abstract contract IUniswapV2Router02 {

	function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        virtual
        returns (uint[] memory amounts);
        
}