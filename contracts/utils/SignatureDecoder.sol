// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library SignatureDecoder {
    /*

        Signature:
            [0:20]: `validator address`
            [20:24]: n = `validator signature length`, bytes4 max to 16777215 bytes
            [24:24+n]: `validator signature`
            [24+n:]: `hook signature` [optional]

        `hook signature`:
            [0:20]: `first hook address`
            [20:24]: n1 = `first hook signature length`, bytes4 max to 16777215 bytes
            [24:24+n1]: `first hook signature`

            `[optional]`
            [24+n1:24+n1+20]: `second hook signature` 
            [24+n1+20:24+n1+24]: n2 = `second hook signature length`, bytes4 max to 16777215 bytes
            [24+n1+24:24+n1+24+n2]: `second hook signature`

            ...
     */
    function signatureSplit(bytes calldata self)
        internal
        pure
        returns (address validator, bytes calldata validatorSignature, bytes calldata hookSignature)
    {
        validator = address(bytes20(self[0:20]));
        uint32 validatorSignatureLength = uint32(bytes4(self[20:24]));
        uint256 hookSignatureStartAt;
        unchecked {
            hookSignatureStartAt = 24 + validatorSignatureLength;
        }
        validatorSignature = self[24:hookSignatureStartAt];
        hookSignature = self[hookSignatureStartAt:];
    }
}
