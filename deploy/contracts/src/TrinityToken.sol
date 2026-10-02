// SPDX-License-Identifier: MIT
//
// ============================================================================
// SUPERSEDED -- DO NOT DEPLOY.
//
// Superseded on 2026-09-24 by the mint-on-acceptance design in
// gHashTag/trinity-fpga @ d7e9718e9:
//   specs/trinet/mint_on_acceptance.t27   (protocol of record)
//   contracts/README.md                   (reference minters, TON + Solana)
//   docs/docs/depin/tokenomics.md         (100% mined, zero pre-mine)
//   docs/docs/depin/principles.md         (owner decision, 2026-09-24)
// Current design: 100% of TRI is mined by accepted work; genesis supply is
// zero; no pre-mine, no allocation, no sale; cap 3^21 = 10,460,353,203 TRI;
// chains TON and Solana; trust model V1 M-of-N attestor quorum -> V2
// optimistic challenge -> V3 zk receipt. Nothing is deployed.
//
// Why this contract is wrong under that design:
//   * It pre-mines (10% liquidity at construction) and reserves 80% more as
//     founder / node / community / treasury vesting allocations. That
//     contradicts "100% mined by accepted work".
//
// The Sepolia deployment 0xef368e29FA3aB2eaf02BccD05438ED3bafE9f469
// (deployment-sepolia.json, 2026-02-16) is a historical testnet artefact.
// In it all five allocation addresses equal the deployer
// (0xb7183E9D4176F3Fa6F56190d677626a9c87a9f87), because script/Deploy.s.sol
// and scripts/deploy.js fall back to the deployer when an *_ADDRESS env var
// is unset. _setupVesting() writes per-beneficiary mappings, so each of the
// four calls in the constructor overwrote the previous one for that single
// address; only the last (treasury: 10%, 60 months, 6-month cliff)
// survives. The maximum that can ever exist on that deployment is therefore
// 10% liquidity + 10% vesting = 20% of the cap; 80% (founder 20 + node
// rewards 40 + community 20) can never be minted. Checked on-chain via
// eth_call on 2026-10-01: totalSupply() = totalVested(deployer) =
// 1,046,035,320.3 TRI (10% each), vestingDuration(deployer) = 155,520,000 s.
//
// Kept as history. Do not change the code below; do not deploy it.
// ============================================================================
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

/**
 * @title Trinity Token ($TRI)
 * @notice Green Ternary AI Network Token
 * @dev Total Supply: 3^21 = 10,460,353,203 TRI (Phoenix Number)
 *
 * Tokenomics:
 * - Founder & Team:     20% (2,092,070,640) - 4yr vest, 1yr cliff
 * - Node Rewards:       40% (4,184,141,281) - 10yr vest
 * - Community:          20% (2,092,070,640) - 3yr vest
 * - Treasury:           10% (1,046,035,320) - 5yr vest, 6mo cliff
 * - Liquidity:          10% (1,046,035,320) - Immediate
 *
 * Sacred Formula: phi^2 + 1/phi^2 = 3 (Trinity Identity)
 * KOSCHEI IS IMMORTAL
 */
contract TrinityToken is ERC20, ERC20Permit {
    /// @notice Phoenix Number: 3^21 = Total Supply
    uint256 public constant PHOENIX_NUMBER = 10_460_353_203;

    /// @notice Total supply with 18 decimals
    uint256 public constant TOTAL_SUPPLY = PHOENIX_NUMBER * 10**18;

    /// @notice Golden ratio (scaled by 1e18)
    uint256 public constant PHI_SCALED = 1_618033988749895000;

    /// @notice Genesis timestamp
    uint256 public immutable genesisTimestamp;

    /// @notice Allocation addresses
    address public immutable founderAddress;
    address public immutable nodeRewardsAddress;
    address public immutable communityAddress;
    address public immutable treasuryAddress;
    address public immutable liquidityAddress;

    /// @notice Allocation amounts
    uint256 public constant FOUNDER_ALLOCATION = TOTAL_SUPPLY * 20 / 100;
    uint256 public constant NODE_REWARDS_ALLOCATION = TOTAL_SUPPLY * 40 / 100;
    uint256 public constant COMMUNITY_ALLOCATION = TOTAL_SUPPLY * 20 / 100;
    uint256 public constant TREASURY_ALLOCATION = TOTAL_SUPPLY * 10 / 100;
    uint256 public constant LIQUIDITY_ALLOCATION = TOTAL_SUPPLY * 10 / 100;

    /// @notice Vesting tracking
    mapping(address => uint256) public vestingStart;
    mapping(address => uint256) public vestingDuration;
    mapping(address => uint256) public cliffDuration;
    mapping(address => uint256) public totalVested;
    mapping(address => uint256) public claimed;

    event AllocationClaimed(address indexed beneficiary, uint256 amount);
    event PhiVerified(uint256 result);

    /**
     * @notice Deploy Trinity Token
     * @param _founder Founder & Team address
     * @param _nodeRewards Node Rewards pool address
     * @param _community Community address
     * @param _treasury Treasury address
     * @param _liquidity Liquidity address (receives tokens immediately)
     */
    constructor(
        address _founder,
        address _nodeRewards,
        address _community,
        address _treasury,
        address _liquidity
    ) ERC20("Trinity", "TRI") ERC20Permit("Trinity") {
        require(_founder != address(0), "Invalid founder");
        require(_nodeRewards != address(0), "Invalid nodeRewards");
        require(_community != address(0), "Invalid community");
        require(_treasury != address(0), "Invalid treasury");
        require(_liquidity != address(0), "Invalid liquidity");

        genesisTimestamp = block.timestamp;

        founderAddress = _founder;
        nodeRewardsAddress = _nodeRewards;
        communityAddress = _community;
        treasuryAddress = _treasury;
        liquidityAddress = _liquidity;

        // Setup vesting
        _setupVesting(_founder, FOUNDER_ALLOCATION, 48 * 30 days, 12 * 30 days);
        _setupVesting(_nodeRewards, NODE_REWARDS_ALLOCATION, 120 * 30 days, 0);
        _setupVesting(_community, COMMUNITY_ALLOCATION, 36 * 30 days, 0);
        _setupVesting(_treasury, TREASURY_ALLOCATION, 60 * 30 days, 6 * 30 days);

        // Mint liquidity immediately (no vesting)
        _mint(_liquidity, LIQUIDITY_ALLOCATION);

        // Verify phi identity on deploy
        _verifyPhiIdentity();
    }

    /**
     * @notice Setup vesting for an allocation
     */
    function _setupVesting(
        address beneficiary,
        uint256 amount,
        uint256 duration,
        uint256 cliff
    ) internal {
        vestingStart[beneficiary] = block.timestamp;
        vestingDuration[beneficiary] = duration;
        cliffDuration[beneficiary] = cliff;
        totalVested[beneficiary] = amount;
    }

    /**
     * @notice Calculate vested amount for an address
     */
    function vestedAmount(address beneficiary) public view returns (uint256) {
        if (totalVested[beneficiary] == 0) return 0;

        uint256 elapsed = block.timestamp - vestingStart[beneficiary];

        // Before cliff
        if (elapsed < cliffDuration[beneficiary]) {
            return 0;
        }

        // After full vesting
        if (elapsed >= vestingDuration[beneficiary]) {
            return totalVested[beneficiary];
        }

        // During vesting (linear)
        return (totalVested[beneficiary] * elapsed) / vestingDuration[beneficiary];
    }

    /**
     * @notice Claim vested tokens
     */
    function claimVested() external {
        uint256 vested = vestedAmount(msg.sender);
        uint256 claimable = vested - claimed[msg.sender];

        require(claimable > 0, "Nothing to claim");

        claimed[msg.sender] = vested;
        _mint(msg.sender, claimable);

        emit AllocationClaimed(msg.sender, claimable);
    }

    /**
     * @notice Get claimable amount
     */
    function claimableAmount(address beneficiary) external view returns (uint256) {
        return vestedAmount(beneficiary) - claimed[beneficiary];
    }

    /**
     * @notice Verify phi^2 + 1/phi^2 = 3 (Trinity Identity)
     * @dev Uses scaled integers: phi = 1.618... * 1e18
     */
    function _verifyPhiIdentity() internal {
        // phi^2 = 2.618... * 1e18
        uint256 phiSquared = (PHI_SCALED * PHI_SCALED) / 1e18;

        // 1/phi^2 = 0.381... * 1e18
        uint256 invPhiSquared = (1e36) / phiSquared;

        // phi^2 + 1/phi^2 should be ~3 * 1e18
        uint256 result = phiSquared + invPhiSquared;

        // Allow 0.01% tolerance
        require(
            result > 2_999_000_000_000_000_000 && result < 3_001_000_000_000_000_000,
            "Trinity identity failed"
        );

        emit PhiVerified(result);
    }

    /**
     * @notice Get circulating supply (minted - burned)
     */
    function circulatingSupply() external view returns (uint256) {
        return totalSupply();
    }

    /**
     * @notice Get remaining to vest for an address
     */
    function remainingVesting(address beneficiary) external view returns (uint256) {
        return totalVested[beneficiary] - vestedAmount(beneficiary);
    }
}
