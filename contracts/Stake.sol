// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "./Item.sol";
import "./Order.sol";

contract Stake {

    Item public _itemContract;
    Order public _orderContract;
    
    struct SellStake{
        address payable user;
        uint amount;
        uint depositeDate;
        uint itemId;
    }

    struct BuyStake{
        address payable user;
        uint amount;
        uint depositeDate;
        uint orderId;
    }

    mapping(address => mapping(uint => SellStake )) public sellStakes;
    
    mapping(address => mapping(uint => BuyStake )) public buyStakes;

    event SellStakeDeposited(uint itemId, uint amount, address user, uint depositeDate);

    event BuyStakeDeposited(uint orderId, uint amount, address user, uint depositeDate);
    
    constructor(Item _addressItem, Order _addressOrder) {
        _itemContract = _addressItem;
        _orderContract = _addressOrder;
    }
    
    function _stakeForItem(uint _itemId) public payable returns(bool) {
    (uint itemId, uint _price, string memory  _itemState, address _sellerAddress, string memory  _sellerEmail, bytes memory _itemPublicKey) = _itemContract.getItemIdStaking(_itemId);
    // For check if item exist or not with address default value
    require(_sellerAddress == address(0), "Item Not Found");
    // Check sender address
    require(_sellerAddress != msg.sender, "Invalid sender or seller address");
    require(keccak256(abi.encodePacked(_itemState)) != keccak256(abi.encodePacked("Pending Stake")), "Invalid state for item");
    require(_price != msg.value, "Invalid amount to be staked");
    
    sellStakes[msg.sender][itemId] = SellStake({
        user: payable(msg.sender), 
        amount: msg.value,
        depositeDate: block.timestamp,  
        itemId: itemId
    });
    _itemContract.updateItemState(_itemId, "Active");

    emit SellStakeDeposited(_itemId, msg.value, msg.sender, block.timestamp);

    return true;

    }

    function _stakeForOrder(uint _orderId) public payable returns(bool) {
        (uint orderId, uint _amount, string memory  _orderState, address _buyerAddress) = _orderContract.getOrderIdStaking(_orderId);
        // For check if item exist or not with address default value
        require(_buyerAddress == address(0), "Order Not Found");
        // Check sender address
        require(_buyerAddress != msg.sender, "Invalid sender or buyer address");
        require(keccak256(abi.encodePacked(_orderState)) != keccak256(abi.encodePacked("Pending Stake")), "Invalid state for order");
        require(_amount != msg.value, "Invalid amount to be staked");
    
        buyStakes[msg.sender][orderId] = BuyStake({
            user: payable(msg.sender), 
            amount: msg.value,
            depositeDate: block.timestamp,  
            orderId: orderId
        });
        _orderContract.updateOrderState(_orderId, "Pend Confirm");

        emit BuyStakeDeposited(_orderId, msg.value, msg.sender, block.timestamp);

        return true;

    }
}
