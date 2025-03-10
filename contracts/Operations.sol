// SPDX-License-Identifier: MIT OR Apache-2.0

pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import "./Bytes.sol";
import "./Utils.sol";
import "hardhat/console.sol"; //for debugging

/// @title Fluidex operations tools
library Operations {
    /// @notice Config parameters, generated from circuit parameters
    uint8 constant BALANCE_BITS = 3;
    uint8 constant ACCOUNT_BITS = 4;
    uint8 constant ORDER_BITS = 4;
    uint256 constant TX_PUBDATA_BYTES = 33;

    /// @dev Expected average period of block creation
    uint256 internal constant BLOCK_PERIOD = 15 seconds;

    /// @dev Expiration delta for priority request to be satisfied (in seconds)
    /// @dev NOTE: Priority expiration should be > (EXPECT_VERIFICATION_IN * BLOCK_PERIOD)
    /// @dev otherwise incorrect block with priority op could not be reverted.
    uint256 internal constant PRIORITY_EXPIRATION_PERIOD = 7 days;

    /// @dev Expiration delta for priority request to be satisfied (in ETH blocks)
    uint256 internal constant PRIORITY_EXPIRATION =
        PRIORITY_EXPIRATION_PERIOD / BLOCK_PERIOD;

    /// @notice Fluidex circuit operation type
    enum OpType {
        Deposit,
        Registry
    }

    function hashPubData(bytes calldata _public_data, uint256 pos)
        internal
        pure
        returns (bytes20)
    {
        return
            Utils.hashBytesToBytes20(_public_data[pos:pos + TX_PUBDATA_BYTES]);
    }

    // Registry L2key pubdata
    struct Registry {
        uint32 accountId;
        bytes32 l2key;
    }

    // Deposit pubdata
    struct Deposit {
        uint32 accountId;
        uint16 tokenId;
        uint128 amount;
    }

    function scaleTokenValueToAmount(uint256 value, uint8 scale)
        internal
        pure
        returns (uint128)
    {
        require(scale > 0, "Known token must has a scaling");
        return uint128(value / (10**scale));
    }

    function hashOpDataFromBuf(bytes memory buf)
        internal
        pure
        returns (bytes20)
    {
        bytes memory truncatedBuf = new bytes(TX_PUBDATA_BYTES);
        for (uint256 i = 0; i < TX_PUBDATA_BYTES; i++) {
            truncatedBuf[i] = buf[i];
        }

        return Utils.hashBytesToBytes20(truncatedBuf);
    }

    /// Serialize registry pubdata
    function writeRegistryPubdataForPriorityQueue(Registry memory op)
        internal
        pure
        returns (bytes20)
    {
        uint256 encoded_1 = 0;
        uint8 offset = 0;
        encoded_1 += Bytes.shiftAndReverseBits8(uint8(1), offset); //100 in bits
        offset += 3;
        encoded_1 += Bytes.shiftAndReverseBits32(op.accountId, offset);
        offset += ACCOUNT_BITS;
        uint8 sign = op.l2key[31] & 0x80 != 0 ? 1 : 0;
        encoded_1 += Bytes.shiftAndReverseBits8(sign, offset);
        offset += 1;
        uint256 ay = uint256(op.l2key);
        ay -= (uint8(op.l2key[31]) - uint8(op.l2key[31] & 0x7f));
        //notice babyjub consider the read bytes as LITTLE-endian integer
        ay = Bytes.swapBytes(ay);
        encoded_1 += Bytes.shiftAndReverseBits(ay, offset);
        //calc the resident of bits in ay
        ay >>= (256 - offset);
        uint256 encoded_2 = Bytes.shiftAndReverseBits(ay, 0);

        return hashOpDataFromBuf(abi.encodePacked(encoded_1, encoded_2));
    }

    /// Serialize deposit pubdata
    function writeDepositPubdataForPriorityQueue(Deposit memory op)
        internal
        pure
        returns (bytes20)
    {
        uint256 encoded_1 = 0;
        uint8 offset = 0;
        encoded_1 += Bytes.shiftAndReverseBits8(uint8(0), offset); //000 in bits
        offset += 3;
        encoded_1 += Bytes.shiftAndReverseBits32(op.accountId, offset);
        offset += ACCOUNT_BITS;
        //according to the encoding scheme we need to encode account id twice
        encoded_1 += Bytes.shiftAndReverseBits32(op.accountId, offset);
        offset += ACCOUNT_BITS;
        encoded_1 += Bytes.shiftAndReverseBits16(op.tokenId, offset);
        offset += BALANCE_BITS;
        assert(offset <= 128);

        encoded_1 += Bytes.shiftAndReverseBits128(op.amount, offset);

        return hashOpDataFromBuf(abi.encodePacked(encoded_1, uint256(0)));
    }
}
