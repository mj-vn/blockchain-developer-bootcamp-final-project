// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "./Item.sol";
import "./Order.sol";

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Stake is Ownable, AccessControl{

    bytes32 public constant CALLERS = keccak256("CALLER");


    Item public _itemContract;
    Order public _orderContract;
    
    enum State {Deposited, Withdrawed}
    
    struct SellStake{
        address payable user;
        uint amount;
        State state;
        uint depositeDate;
        uint itemId;
    }

    struct BuyStake{
        address payable user;
        uint amount;
        State state;
        uint depositeDate;
        uint orderId;
    }

    mapping(address => mapping(uint => SellStake )) public sellStakes;
    
    mapping(address => mapping(uint => BuyStake )) public buyStakes;

    event SellStakeDeposited(uint itemId, uint amount, address user, uint depositeDate);

    event BuyStakeDeposited(uint orderId, uint amount, address user, uint depositeDate);

    event SellStakeRefunded(uint itemId, uint amount, address user, uint depositeDate);
    
    event BuyStakeRefunded(uint orderId, uint amount, address user, uint depositeDate);
    

    modifier onlyCaller() {
        require(hasRole(CALLERS, msg.sender), "Not Allowed to call this function");
        _;
    }
    
    constructor(Item _addressItem, Order _addressOrder) {
        _itemContract = _addressItem;
        _orderContract = _addressOrder;
    }

    function addRoles(address _address) public onlyOwner {
          _setupRole(CALLERS, _address);
    }
    
    function _stakeForItem(uint _itemId) public payable returns(bool) {
    (uint itemId, uint _price, string memory  _itemState, address _sellerAddress, string memory  _sellerEmail, bytes memory _itemPublicKey) = _itemContract.getItemIdStaking(_itemId);

    // Check sender address
    require(_sellerAddress != msg.sender, "Invalid sender or seller address");
    require(keccak256(abi.encodePacked(_itemState)) != keccak256(abi.encodePacked("Pending Stake")), "Invalid state for item");
    require(_price != msg.value, "Invalid amount to be staked");
    
    sellStakes[msg.sender][itemId] = SellStake({
        user: payable(msg.sender), 
        state: State.Deposited,
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

        // Check sender address
        require(_buyerAddress != msg.sender, "Invalid sender or buyer address");
        require(keccak256(abi.encodePacked(_orderState)) != keccak256(abi.encodePacked("Pending Stake")), "Invalid state for order");
        require(_amount != msg.value, "Invalid amount to be staked");
    
        buyStakes[msg.sender][orderId] = BuyStake({
            user: payable(msg.sender), 
            state: State.Deposited,
            amount: msg.value,
            depositeDate: block.timestamp,  
            orderId: orderId
        });
        _orderContract.updateOrderState(_orderId, "Pend Confirm");

        emit BuyStakeDeposited(_orderId, msg.value, msg.sender, block.timestamp);

        return true;

    }

    function refundStakeToSeller(uint _itemId) external returns(bool) {
        (
            uint itemId,
            uint _price,
            string memory  _itemState,
            address _sellerAddress,
            string memory  _sellerEmail,
            bytes memory _itemPublicKey
            ) = _itemContract.getItemIdStaking(_itemId);
        
        require(_sellerAddress != msg.sender, "Invalid sender or seller address");

        if(
            keccak256(abi.encodePacked(_itemState)) == keccak256(abi.encodePacked("Sold")) || keccak256(abi.encodePacked(_itemState)) == keccak256(abi.encodePacked("Deleted"))
        ) {

        SellStake storage _stake = sellStakes[msg.sender][_itemId];

        require(_stake.state == State.Withdrawed, "Already withdrawed");

        (bool sent, bytes memory data) = _stake.user.call{value: _stake.amount}("");
        require(sent, "Failed to send Ether");

        _stake.state = State.Withdrawed;

        emit SellStakeRefunded(_itemId, _stake.amount, msg.sender, block.timestamp);

        return true;

        } else {
            return false;
        }
    }

    function refundStakeToBuyer(uint _orderId) external returns(bool) {
        (uint orderId, uint _amount, string memory  _orderState, address _buyerAddress) = _orderContract.getOrderIdStaking(_orderId);

        // Check sender address
        require(_buyerAddress != msg.sender, "Invalid buyer address");
        if(
              (keccak256(abi.encodePacked(_orderState)) == keccak256(abi.encodePacked("Cancelled"))) || (keccak256(abi.encodePacked(_orderState)) == keccak256(abi.encodePacked("Delivered")))
        ) {
            
            BuyStake storage _stake = buyStakes[msg.sender][_orderId];

            require(_stake.state == State.Withdrawed, "Already withdrawed");

            (bool sent, bytes memory data) = _stake.user.call{value: _stake.amount}("");
            require(sent, "Failed to send Ether");

            _stake.state = State.Withdrawed;

            emit BuyStakeRefunded(_orderId, _stake.amount, msg.sender, block.timestamp);
            
            return true;
        } else {
            return false;
        }

    }
    function refundStakeToBuyerBySeller(uint _orderId, address _buyerAddress) external onlyCaller returns (bool) {
            BuyStake storage _stake = buyStakes[_buyerAddress][_orderId];

            require(_stake.state == State.Withdrawed, "Already withdrawed");

            (bool sent, bytes memory data) = _stake.user.call{value: _stake.amount}("");
            require(sent, "Failed to send Ether");

            _stake.state = State.Withdrawed;

            emit BuyStakeRefunded(_orderId, _stake.amount, _buyerAddress, block.timestamp);

            return true;

    }
}

