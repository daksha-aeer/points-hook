pragma solidity 0.8.26;

import {BaseHook} from "v4-periphery/src/utils/BaseHook.sol";
import {ERC1155} from "solmate/src/tokens/ERC1155.sol";

import {Currency} from "v4-core/types/Currency.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {PoolId} from "v4-core/types/PoolId.sol";
import {BalanceDelta} from "v4-core/types/BalanceDelta.sol";
import {SwapParams, ModifyLiquidityParams} from "v4-core/types/PoolOperation.sol";

import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";

import {Hooks} from "v4-core/libraries/Hooks.sol";

contract PointsHook is BaseHook, ERC1155 {
    constructor(IPoolManager _manager) BaseHook(_manager) {}

    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: false,
            afterInitialize: false,
            beforeAddLiquidity: false,
            beforeRemoveLiquidity: false,
            afterAddLiquidity: false,
            afterRemoveLiquidity: false,
            beforeSwap: false,
            afterSwap: true,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: false,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    function uri(uint256) public view virtual override returns (string memory) {
        return "https://api.example.com/token/{id}";
    }

    mapping(address => uint256) public userTotalVolume;

    function _afterSwap(
        address,
        PoolKey calldata key,
        SwapParams calldata swapParams,
        BalanceDelta delta,
        bytes calldata hookData
    ) internal override returns (bytes4, int128) {
        if (!key.currency0.isAddressZero()) return (this.afterSwap.selector, 0);
        if (!swapParams.zeroForOne) return (this.afterSwap.selector, 0);

        uint256 ethSpendAmount = uint256(int256(-delta.amount0()));

        // feature - reward tier
        address user = abi.decode(hookData, address);
        if (user == address(0)) return (this.afterSwap.selector, 0);
        uint256 currentTotalVolume = userTotalVolume[user];

        uint256 pointsForSwap;

        if (currentTotalVolume > 10 ether) {
            //Tier 1: 20% rate
            pointsForSwap = ethSpendAmount / 5;
        } else if (currentTotalVolume > 5 ether) {
            //Tier 2: 10% rate
            pointsForSwap = ethSpendAmount / 10;
        } else {
            //Tier 3: 5% rate
            pointsForSwap = ethSpendAmount / 20;
        }

        _assignPoints(key.toId(), hookData, pointsForSwap);
        userTotalVolume[user] = currentTotalVolume + ethSpendAmount;

        return (this.afterSwap.selector, 0);
    }

    function _assignPoints(PoolId poolId, bytes calldata hookData, uint256 points) internal {
        // if no hookdata passed, no points assigned
        if (hookData.length == 0) return;

        // extracting user address from hookData
        address user = abi.decode(hookData, (address));

        if (user == address(0)) return;

        uint256 poolIdUint = uint256(PoolId.unwrap(poolId));
        _mint(user, poolIdUint, points, "");
    }
}

