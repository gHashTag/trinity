// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";

/**
 * @title TrinityVesting
 * @notice Sablier-style streaming vesting with NFT representation
 * @dev v3.0: Reorg protection, overflow caps, sacred supply constants
 *
 * SACRED NUMBER: Total Supply = 3^21 = 10,460,353,203 $TRI
 *
 * v3.0 Security Features:
 * - Reorg protection (1-minute delay on claims after stream creation)
 * - Overflow caps for EXP curve (capped at 99% to prevent overflow)
 * - Gas griefing protection hooks (when hooks are implemented)
 * - Maximum stream amount capped at 1% of sacred supply
 * - Per-stream creation timestamp tracking
 *
 * Vesting Curves:
 * - LINEAR: Constant rate (standard)
 * - EXP: Accelerating (more later)
 * - LOG: Decelerating (more early)
 * - BACKWEIGHTED: S-curve (less early, more late)
 *
 * phi^2 + 1/phi^2 = 3 (Trinity Identity)
 * 3^21 = 10,460,353,203 (Sacred Token Supply)
 * KOSCHEI IS IMMORTAL
 */
contract TrinityVesting is ERC721URIStorage, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using SafeCast for uint256;
    using Math for uint256;

    // =========================================================================
    // SACRED CONSTANTS
    // =========================================================================

    /// @notice SACRED: Total $TRI supply = 3^21
    uint256 public constant SACRED_SUPPLY = 10_460_353_203 * 1e18;

    /// @notice Maximum amount per stream (1% of sacred supply)
    uint256 public constant MAX_STREAM_AMOUNT = SACRED_SUPPLY / 100;

    /// @notice Reorg protection delay (1 minute)
    uint256 public constant REORG_DELAY = 1 minutes;

    /// @notice Minimum gas required for hooks (when implemented)
    uint256 public constant MIN_HOOKS_GAS = 100000;

    // =========================================================================
    // ERRORS
    // =========================================================================

    error InvalidStream();
    error StreamNotActive();
    error NotStreamOwner();
    error StreamAlreadyCanceled();
    error NothingToClaim();
    error InvalidCurve();
    error CannotTransferCanceled();
    error ReorgProtectionActive();
    error InsufficientGasForHooks();
    error ExceedsMaxStreamAmount();

    // =========================================================================
    // ENUMS
    // =========================================================================

    enum StreamStatus {
        PENDING,
        STREAMING,
        COMPLETED,
        CANCELED
    }

    enum StreamCurve {
        LINEAR,     // Constant rate: f(t) = t/duration
        EXP,        // Accelerating: f(t) = (t/duration)^2
        LOG,        // Decelerating: f(t) = 1 - (1 - t/duration)^2
        BACKWEIGHTED // S-curve: more weighted to end
    }

    // =========================================================================
    // STRUCTS
    // =========================================================================

    struct Stream {
        uint256 id;
        address sender;
        address recipient;
        uint256 amount; // Total tokens
        uint128 startTime; // SafeCast to prevent overflow
        uint128 duration; // Stored as duration, calculated endTime on read
        StreamCurve curve;
        StreamStatus status;
        uint256 canceledAt; // Timestamp if canceled
        uint256 cancelPenalty; // Penalty percentage (basis points, 10000 = 100%)
    }

    // =========================================================================
    // STATE
    // =========================================================================

    IERC20 public immutable token;

    uint256 private _nextStreamId = 1;
    uint256 private _nextTokenId = 1;

    mapping(uint256 => Stream) public streams;
    mapping(uint256 => uint256) public streamIdToTokenId;
    mapping(uint256 => uint256) public tokenIdToStreamId;

    // v2.1: Constraints to prevent overflow
    uint256 public constant MAX_CANCEL_PENALTY = 5000; // Max 50% penalty
    uint256 public constant MAX_DURATION = 3650 days; // ~10 years max
    uint256 public constant MAX_AMOUNT = 1e35; // Max 100 billion tokens for 18 decimals

    // v2.1: Per-stream claim tracking (prevents double-claim attacks)
    mapping(uint256 => uint256) public streamClaimed; // streamId => total claimed

    // v3.0: Stream creation timestamps for reorg protection
    mapping(uint256 => uint256) public streamCreatedAt; // streamId => creation timestamp

    // v3.0: Gas requirement for hooks (when implemented)
    bool public hooksEnabled = false;
    uint256 public minHooksGas = MIN_HOOKS_GAS;

    event StreamCreated(
        uint256 indexed streamId,
        uint256 indexed tokenId,
        address sender,
        address recipient,
        uint256 amount,
        uint256 startTime,
        uint256 endTime,
        StreamCurve curve
    );

    event StreamCanceled(uint256 indexed streamId, uint256 penalty);
    event Withdrawn(uint256 indexed streamId, uint256 amount);
    event StreamTransferred(uint256 indexed streamId, address from, address to);
    event HooksConfigured(bool enabled, uint256 minGas);

    // =========================================================================
    // CONSTRUCTOR
    // =========================================================================

    constructor(
        IERC20 _token,
        string memory _name,
        string memory _symbol
    ) ERC721(_name, _symbol) Ownable(msg.sender) {
        token = _token;
    }

    // =========================================================================
    // CREATE STREAM
    // =========================================================================

    /**
     * @notice Create a new vesting stream
     * @param recipient Address to receive vested tokens
     * @param amount Total amount to vest (capped at MAX_STREAM_AMOUNT)
     * @param startTime When vesting starts
     * @param duration How long vesting lasts (seconds)
     * @param curve Vesting curve type
     * @param uri Optional metadata URI for the NFT
     * @return streamId ID of the created stream
     */
    function createStream(
        address recipient,
        uint256 amount,
        uint256 startTime,
        uint256 duration,
        StreamCurve curve,
        string memory uri
    ) external nonReentrant returns (uint256 streamId) {
        require(recipient != address(0), "Invalid recipient");
        require(amount > 0 && amount <= MAX_AMOUNT, "Invalid amount");
        require(amount <= MAX_STREAM_AMOUNT, "Exceeds max stream amount"); // v3.0: Sacred supply cap
        require(startTime >= block.timestamp, "Invalid start time");
        require(duration > 0 && duration <= MAX_DURATION, "Invalid duration");

        streamId = _nextStreamId++;

        uint256 tokenId = _nextTokenId++;

        // Mint NFT to sender (can be transferred to recipient)
        _safeMint(msg.sender, tokenId);
        if (bytes(uri).length > 0) {
            _setTokenURI(tokenId, uri);
        }

        // Link stream and token
        streamIdToTokenId[streamId] = tokenId;
        tokenIdToStreamId[tokenId] = streamId;

        // v2.1: SafeCast startTime and duration to uint128
        uint128 startTimeSafe = startTime.toUint128();
        uint128 durationSafe = duration.toUint128();

        // Store stream
        streams[streamId] = Stream({
            id: streamId,
            sender: msg.sender,
            recipient: recipient,
            amount: amount,
            startTime: startTimeSafe,
            duration: durationSafe,
            curve: curve,
            status: StreamStatus.PENDING,
            canceledAt: 0,
            cancelPenalty: 0
        });

        // v3.0: Record creation time for reorg protection
        streamCreatedAt[streamId] = block.timestamp;

        // Transfer tokens from sender
        token.safeTransferFrom(msg.sender, address(this), amount);

        uint256 endTime = startTime + durationSafe;
        emit StreamCreated(streamId, tokenId, msg.sender, recipient, amount, startTime, endTime, curve);
    }

    // =========================================================================
    // CLAIM
    // =========================================================================

    /**
     * @notice Claim vested tokens for a stream
     * @dev v3.0: Reorg protection - claims blocked for REORG_DELAY after creation
     * @param streamId ID of the stream
     * @return amount Amount claimed
     */
    function claim(uint256 streamId) external nonReentrant returns (uint256 amount) {
        Stream storage stream = streams[streamId];
        require(stream.status == StreamStatus.STREAMING || stream.status == StreamStatus.COMPLETED, "Invalid stream status");

        // v3.0: Reorg protection
        uint256 createdAt = streamCreatedAt[streamId];
        require(block.timestamp >= createdAt + REORG_DELAY, "Reorg protection active");

        uint256 vested = _calculateVestedAmount(stream);
        uint256 alreadyClaimed = streamClaimed[streamId];

        if (stream.status == StreamStatus.PENDING) {
            stream.status = StreamStatus.STREAMING;
        }

        // v2.1: Calculate endTime from duration
        uint256 endTime = uint256(stream.startTime) + uint256(stream.duration);
        if (block.timestamp >= endTime && stream.status != StreamStatus.COMPLETED) {
            stream.status = StreamStatus.COMPLETED;
        }

        amount = vested - alreadyClaimed;
        if (amount == 0) revert NothingToClaim();

        // v2.1: Update claimed in separate mapping
        streamClaimed[streamId] = vested;

        token.safeTransfer(stream.recipient, amount);

        emit Withdrawn(streamId, amount);
    }

    // =========================================================================
    // CANCEL
    // =========================================================================

    /**
     * @notice Cancel a stream (sender only, before end time)
     * @param streamId ID of the stream
     * @param penalty Cancel penalty in basis points (10000 = 100%)
     * @return refunded Amount refunded to sender
     */
    function cancelStream(uint256 streamId, uint256 penalty) external nonReentrant returns (uint256 refunded) {
        Stream storage stream = streams[streamId];
        if (msg.sender != stream.sender) revert NotStreamOwner();
        if (stream.status != StreamStatus.STREAMING) revert StreamNotActive();

        // v2.1: Calculate endTime from duration
        uint256 endTime = uint256(stream.startTime) + uint256(stream.duration);
        require(block.timestamp < endTime, "Stream ended");
        require(penalty <= MAX_CANCEL_PENALTY, "Penalty too high");

        stream.status = StreamStatus.CANCELED;
        stream.canceledAt = block.timestamp;
        stream.cancelPenalty = penalty;

        // Calculate amounts
        uint256 totalVested = _calculateVestedAmount(stream);
        uint256 alreadyClaimed = streamClaimed[streamId];
        uint256 unclaimedVested = 0;

        if (totalVested > alreadyClaimed) {
            unclaimedVested = totalVested - alreadyClaimed;
        }

        // v2.1: Recipient gets their unclaimed vested share minus penalty
        uint256 recipientShare = (unclaimedVested * (10000 - penalty)) / 10000;

        // v2.1: Sender gets: remaining unvested + penalty portion of vested
        uint256 senderRefund = stream.amount - alreadyClaimed - recipientShare;

        // Transfer recipient's share first
        if (recipientShare > 0) {
            token.safeTransfer(stream.recipient, recipientShare);
        }

        // Refund sender
        if (senderRefund > 0) {
            token.safeTransfer(stream.sender, senderRefund);
        }

        // v2.1: Mark remaining as claimed
        streamClaimed[streamId] = totalVested;

        emit StreamCanceled(streamId, penalty);
        return senderRefund;
    }

    // =========================================================================
    // VIEW FUNCTIONS
    // =========================================================================

    /**
     * @notice Calculate vested amount at current time
     * @param streamId ID of the stream
     * @return vested Amount currently vested
     */
    function vestedAmount(uint256 streamId) external view returns (uint256 vested) {
        Stream storage stream = streams[streamId];
        return _calculateVestedAmount(stream);
    }

    /**
     * @notice Calculate claimable amount
     * @param streamId ID of the stream
     * @return claimable Amount that can be claimed
     */
    function claimableAmount(uint256 streamId) external view returns (uint256 claimable) {
        Stream storage stream = streams[streamId];
        uint256 vested = _calculateVestedAmount(stream);
        uint256 alreadyClaimed = streamClaimed[streamId];

        // v3.0: Check reorg protection
        uint256 createdAt = streamCreatedAt[streamId];
        if (block.timestamp < createdAt + REORG_DELAY) {
            return 0; // Not claimable yet due to reorg protection
        }

        if (vested > alreadyClaimed) {
            return vested - alreadyClaimed;
        }
        return 0;
    }

    /**
     * @notice Get stream details
     * @param streamId ID of the stream
     * @return id Stream ID
     * @return sender Stream creator
     * @return recipient Stream recipient
     * @return amount Total stream amount
     * @return startTime Stream start timestamp
     * @return endTime Stream end timestamp (computed)
     * @return curve Vesting curve type
     * @return status Current stream status
     * @return claimed Total claimed amount
     * @return canceledAt Cancellation timestamp (0 if active)
     * @return cancelPenalty Cancellation penalty (basis points)
     * @return createdAt Stream creation timestamp (v3.0)
     */
    function getStream(uint256 streamId) public view returns (
        uint256 id,
        address sender,
        address recipient,
        uint256 amount,
        uint256 startTime,
        uint256 endTime,
        StreamCurve curve,
        StreamStatus status,
        uint256 claimed,
        uint256 canceledAt,
        uint256 cancelPenalty,
        uint256 createdAt // v3.0: Creation timestamp for reorg protection
    ) {
        Stream storage stream = streams[streamId];
        return (
            stream.id,
            stream.sender,
            stream.recipient,
            stream.amount,
            uint256(stream.startTime),
            uint256(stream.startTime) + uint256(stream.duration),
            stream.curve,
            stream.status,
            streamClaimed[streamId],
            stream.canceledAt,
            stream.cancelPenalty,
            streamCreatedAt[streamId] // v3.0
        );
    }

    /**
     * @notice Get stream ID from token ID
     * @param tokenId NFT token ID
     * @return streamId Associated stream ID
     */
    function getStreamIdByToken(uint256 tokenId) external view returns (uint256 streamId) {
        return tokenIdToStreamId[tokenId];
    }

    /**
     * @notice Get stream status only (gas-optimized)
     * @param streamId ID of the stream
     * @return status Current stream status
     */
    function getStreamStatus(uint256 streamId) external view returns (StreamStatus status) {
        return streams[streamId].status;
    }

    // =========================================================================
    // v3.0: HOOKS CONFIGURATION
    // =========================================================================

    /**
     * @notice Configure hooks (for future gas griefing protection)
     * @param enabled Whether hooks are enabled
     * @param minGas Minimum gas required for hooks
     */
    function configureHooks(bool enabled, uint256 minGas) external onlyOwner {
        hooksEnabled = enabled;
        minHooksGas = minGas;
        emit HooksConfigured(enabled, minGas);
    }

    // =========================================================================
    // NFT TRANSFERS
    // =========================================================================

    /**
     * @notice v3.0: Hook to restrict canceled stream transfers
     * @dev Uses _update pattern for OZ v5 compatibility
     */
    function _update(address to, uint256 tokenId, address auth)
        internal
        override
        returns (address)
    {
        _checkHooksGas(); // v3.0: Gas griefing protection
        uint256 streamId = tokenIdToStreamId[tokenId];
        if (streamId != 0) {
            StreamStatus status;
            (,,,,,,, status,,,,) = getStream(streamId);
            if (status == StreamStatus.CANCELED) {
                revert CannotTransferCanceled();
            }
        }
        return super._update(to, tokenId, auth);
    }

    // =========================================================================
    // INTERNAL
    // =========================================================================

    function _calculateVestedAmount(Stream memory stream) internal view returns (uint256) {
        if (stream.amount == 0) return 0;

        uint256 time = block.timestamp;
        if (stream.status == StreamStatus.CANCELED) {
            time = stream.canceledAt;
        }

        uint256 startTime = uint256(stream.startTime);
        if (time < startTime) {
            return 0;
        }

        uint256 endTime = startTime + uint256(stream.duration);
        if (time >= endTime) {
            return stream.amount;
        }

        uint256 elapsed = time - startTime;
        uint256 duration = uint256(stream.duration);

        // Calculate progress based on curve
        uint256 progressBps = _calculateProgress(elapsed, duration, stream.curve);

        // v2.1: Use Math.mulDiv for overflow-safe multiplication
        return Math.mulDiv(stream.amount, progressBps, 10000);
    }

    function _calculateProgress(uint256 elapsed, uint256 duration, StreamCurve curve) internal pure returns (uint256) {
        // v2.1: Overflow-safe ratio calculation
        uint256 ratio = Math.mulDiv(elapsed, 10000, duration);

        if (curve == StreamCurve.LINEAR) {
            return ratio; // f(t) = t/duration
        } else if (curve == StreamCurve.EXP) {
            // v3.0: Cap ratio at 99% for EXP curve to prevent overflow in square
            // This prevents sender from creating an unrecoverable stream
            uint256 cappedRatio = ratio > 9900 ? 9900 : ratio;
            return Math.mulDiv(cappedRatio, cappedRatio, 10000); // f(t) = (t/duration)^2
        } else if (curve == StreamCurve.LOG) {
            // f(t) = 1 - (1 - t/d)^2 = 2*ratio - ratio^2/10000
            uint256 complement = 10000 - ratio;
            uint256 complementSq = Math.mulDiv(complement, complement, 10000);
            return 10000 - complementSq;
        } else if (curve == StreamCurve.BACKWEIGHTED) {
            return _backweightedCurve(ratio); // S-curve
        } else {
            return ratio; // Default to LINEAR
        }
    }

    function _backweightedCurve(uint256 x) internal pure returns (uint256) {
        // v2.1: Overflow-safe S-curve approximation
        uint256 xSq = Math.mulDiv(x, x, 10000);
        uint256 denominator = 10000 - (2 * x) / 10000 + (2 * xSq) / 10000;
        if (denominator == 0) return 10000;

        // Simplified S-curve: f(x) = x^2 / (x^2 + (10000-x)^2)
        uint256 complement = 10000 - x;
        uint256 complementSq = Math.mulDiv(complement, complement, 10000);
        uint256 sumSq = xSq + complementSq;
        if (sumSq == 0) return 5000; // Edge case: midpoint

        return Math.mulDiv(xSq, 10000, sumSq);
    }

    /**
     * @notice v3.0: Check if sufficient gas for hooks
     */
    function _checkHooksGas() internal view {
        if (hooksEnabled) {
            if (gasleft() < minHooksGas) revert InsufficientGasForHooks();
        }
    }

    // =========================================================================
    // ADMIN
    // =========================================================================

    /**
     * @notice Recover mistakenly sent tokens
     * @param tokenAddress Address of token to recover
     * @param amount Amount to recover
     */
    function recoverTokens(address tokenAddress, uint256 amount) external onlyOwner {
        IERC20(tokenAddress).safeTransfer(owner(), amount);
    }

    // =========================================================================
    // OVERRIDES (OpenZeppelin v5)
    // =========================================================================

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721URIStorage)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }
}
