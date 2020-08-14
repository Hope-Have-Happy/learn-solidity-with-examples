/*
    This contract allows anyone to buy tokens on Ethereum with Bitcoin by proving a Bitcoin transaction was sent
    to a particular address (of the token seller) and is then minted to an ethereum address provided by the bitcoin sender.

    Requires:
    this contract has a minter role in the token contract
*/

import "https://raw.githubusercontent.com/James-Sangalli/learn-solidity-with-examples/master/Finance/swaps/bitcoin-to-ethereum-swap/BtcParser.sol";
import "https://raw.githubusercontent.com/summa-tx/bitcoin-spv/master/solidity/contracts/ViewSPV.sol";
pragma solidity ^0.5.10;

interface ERC20Mint {
    function _mint(address account, uint256 amount) external;
}

contract BuyTokensWithBTC {

    bytes20 bitcoinAddressOfTokenSeller;
    address tokenContract; // can be any token type but for this example we use erc20
    uint deadline; //deadline for this token sale in block time
    mapping (bytes32 => bool) claimedBitcoinTransactions;
    uint rate; //rate of tokens to BTC
    ERC20Mint erc20Mint;

    constructor(bytes20 _bitcoinAddressOfTokenSeller, address _tokenContract, uint _deadline, uint _rate) public {
        bitcoinAddressOfTokenSeller = _bitcoinAddressOfTokenSeller;
        tokenContract = _tokenContract;
        deadline = _deadline;
        rate = _rate;
        erc20Mint = ERC20Mint(_tokenContract);
    }

    //UI needs to protect user against sending BTC after the deadline with a margin of safety
    function isStillActive() public view returns (bool) {
        return deadline > block.timestamp;
    }

    /*
        this function proves a btc transaction occured, validates that it went to the right destination and mints coins back
        to the same key that sent the btc. TODO make it work with a specified recipient address for minted coins
    */
    function proveBTCTransactionAndMint(
        bytes memory rawTransaction,
        uint256 transactionHash,
        bytes32 _txid,
        bytes32 _merkleRoot,
        bytes29 _proof,
        uint _index
    ) public returns (bool) {
        require(deadline > block.timestamp);
        require(!claimedBitcoinTransactions[_txid]); //disallow reclaims
        require(ViewSPV.prove(_txid, _merkleRoot, _proof, _index));
        bytes memory senderPubKey = BtcParser.getPubKeyFromTx(rawTransaction);
        //create ethereum address from bitcoin pubkey
        address senderAddress = address(bytes20(keccak256(senderPubKey)));
        //one would be change, the other the amount actually sent
        (uint amt1, bytes20 address1, uint amt2, bytes20 address2) = BtcParser.getFirstTwoOutputs(rawTransaction);
        if(address1 == bitcoinAddressOfTokenSeller) {
            uint amountToMint = amt1 * rate;
            _mintTokens(senderAddress, amountToMint);
        }
        if(address2 == bitcoinAddressOfTokenSeller) {
            uint amountToMint = amt2 * rate;
            _mintTokens(senderAddress, amountToMint);
        }
        claimedBitcoinTransactions[_txid] = true;
        return true;
    }

    function _mintTokens(address recipient, uint amount) internal {
        erc20Mint._mint(recipient, amount);
    }
}
