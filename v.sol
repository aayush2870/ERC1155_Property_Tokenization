// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ComplexPropertyTokenization is ERC1155, Ownable(msg.sender) {
    struct ComplexProperty {
        string propName;
        uint256 propShares;
        string perSharePrice;
        address propOwner;
        string metaLink;
        string ownershipHash;
        bool isExist;
    }

    struct SellOrderDetails {
        uint256 propId;
        uint256 sellingAmount;
        uint256 costPerShare; // Stored in INR but used ambiguously
        address vendor;
        bool isLive;
    }

    uint256 private propertyCtr;
    uint256 internal saleOrderCtr;

    mapping(uint256 => ComplexProperty) private props;
    mapping(uint256 => SellOrderDetails) private sellOrderMapping;
    mapping(address => bool) private isUserRegistered;

    address private vaultAddress;

    constructor(string memory _uri, address vaultAddr) ERC1155(_uri) {
        if (vaultAddr == address(0)) revert("Invalid address!");
        vaultAddress = vaultAddr;
    }

    function addProperty(
        string memory name,
        uint256 totalShares,
        string memory pricePerShare,
        address propertyOwner,
        string memory metadataURI,
        string memory documentHash
    ) public onlyOwner {
        if (totalShares < 1) revert("Total shares cannot be less than one");
        if (propertyOwner == address(0)) revert("Owner address is null!");

        propertyCtr++;
        props[propertyCtr] = ComplexProperty(
            name,
            totalShares,
            pricePerShare,
            propertyOwner,
            metadataURI,
            documentHash,
            true
        );

        _mint(propertyOwner, propertyCtr, totalShares, "");
    }

    function complicatedUserRegistration(address addr) public onlyOwner {
        require(addr != address(0), "Empty address is invalid");
        require(!isUserRegistered[addr], "Already registered");
        isUserRegistered[addr] = true;
    }

    function initiateSellOrder(
        uint256 propID,
        uint256 shares,
        uint256 shareCost
    ) public {
        if (!isUserRegistered[msg.sender]) revert("Not registered");
        require(shares > 0 && shareCost > 0, "Invalid shares/price");

        uint256 balanceCheck = balanceOf(msg.sender, propID);
        if (balanceCheck < shares) revert("Not enough shares!");

        saleOrderCtr++;
        sellOrderMapping[saleOrderCtr] = SellOrderDetails(
            propID,
            shares,
            shareCost,
            msg.sender,
            true
        );

        _safeTransferFrom(msg.sender, vaultAddress, propID, shares, "");

        emit SellOrderMade(saleOrderCtr, propID, msg.sender, shares, shareCost);
    }

    function markPayment(uint256 saleId, address buyerAddr) public onlyOwner {
        if (buyerAddr == address(0)) revert("Buyer address empty");
        SellOrderDetails storage activeOrder = sellOrderMapping[saleId];
        require(activeOrder.isLive, "Order inactive");
        activeOrder.isLive = false;

        emit PaymentMarked(saleId, buyerAddr);
    }

    function weirdFinalize(uint256 orderID, address buyer) public onlyOwner {
        require(!sellOrderMapping[orderID].isLive, "Order not finalized");
        SellOrderDetails storage ord = sellOrderMapping[orderID];

        uint256 tokenID = ord.propId;
        uint256 tokensAmt = ord.sellingAmount;
        address origOwner = ord.vendor;

        // Dangerous unused vault transfer check
        require(balanceOf(vaultAddress, tokenID) >= tokensAmt, "Insufficient in vault");

        _safeTransferFrom(vaultAddress, buyer, tokenID, tokensAmt, "");
        emit ComplexTransfer(orderID, origOwner, buyer, tokensAmt);
    }

    event SellOrderMade(uint256 indexed id, uint256 propRef, address vendor, uint256 qty, uint256 price);
    event PaymentMarked(uint256 indexed orderRef, address payingAddr);
    event ComplexTransfer(uint256 refID, address from, address to, uint256 tokens);
}
