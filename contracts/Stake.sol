// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "./Item.sol";
import "./Order.sol";

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";


contract Stake is Ownable, AccessControl{
    using Counters for Counters.Counter;

    bytes32 public constant CALLERS = keccak256("CALLER");

    Counters.Counter public stakeCount;


    Item public _itemContract;
    Order public _orderContract;
    
    enum State {Deposited, Withdrawed}
    
    struct SellStake{
        uint Id;
        address payable user;
        uint amount;
        State state;
        uint depositeDate;
        uint itemId;
        uint sellStakesOfSellerIndex;
    }

    struct BuyStake{
        uint Id;
        address payable user;
        uint amount;
        State state;
        uint depositeDate;
        uint orderId;
        uint buyStakesOfBuyerIndex;
    }
    
    mapping(uint => BuyStake) public buyStakes;

    mapping(uint => SellStake) public sellStakes;

    mapping(uint => uint) public sellStakesIdOrderId;

    mapping(address => SellStake[] ) public sellStakesOfSeller;
    
    mapping(address => BuyStake[]) public buyStakesOfBuyer;

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
    (uint itemId, uint _price, string memory  _itemState, address _sellerAddress, string memory  _sellerEmail, string memory _itemPublicKey) = _itemContract.getItemIdStaking(_itemId);

    // Check sender address
    require(_sellerAddress == msg.sender, "Invalid sender or seller address");
    require(keccak256(abi.encodePacked(_itemState)) == keccak256(abi.encodePacked("Pending Stake")), "Invalid state for item");
    require(_price == msg.value, "Invalid amount to be staked");
    
    SellStake memory _stake = SellStake({
        Id: stakeCount.current(),
        user: payable(msg.sender), 
        state: State.Deposited,
        amount: msg.value,
        depositeDate: block.timestamp,  
        itemId: itemId,
        sellStakesOfSellerIndex: sellStakesOfSeller[msg.sender].length
    });

    sellStakes[stakeCount.current()] = _stake;

    stakeCount.increment();

    sellStakesOfSeller[msg.sender].push(_stake);
    _itemContract.updateItemState(_itemId, "Active");

    emit SellStakeDeposited(_itemId, msg.value, msg.sender, block.timestamp);

    return true;

    }

    function _stakeForOrder(uint _orderId) public payable returns(bool) {
        (uint orderId, uint _amount, string memory  _orderState, address _buyerAddress) = _orderContract.getOrderIdStaking(_orderId);

        // Check sender address
        require(_buyerAddress == msg.sender, "Invalid sender or buyer address");
        require(keccak256(abi.encodePacked(_orderState)) == keccak256(abi.encodePacked("Pending Stake")), "Invalid state for order");
        require(_amount == msg.value, "Invalid amount to be staked");
    
        BuyStake memory _stake = BuyStake({
            Id: stakeCount.current(),
            user: payable(msg.sender), 
            state: State.Deposited,
            amount: msg.value,
            depositeDate: block.timestamp,  
            orderId: orderId,
            buyStakesOfBuyerIndex: buyStakesOfBuyer[msg.sender].length
        });

        buyStakes[stakeCount.current()] = _stake;

        sellStakesIdOrderId[orderId] = stakeCount.current();

        stakeCount.increment();

        buyStakesOfBuyer[msg.sender].push(_stake);

        _orderContract.updateOrderState(_orderId, "Pend Confirm");

        emit BuyStakeDeposited(_orderId, msg.value, msg.sender, block.timestamp);

        return true;
    }

    function refundStakeToSeller(uint _itemId, uint _stakeId) external returns(bool) {
        (
            uint itemId,
            uint _price,
            string memory  _itemState,
            address _sellerAddress,
            string memory  _sellerEmail,
            string memory _itemPublicKey
            ) = _itemContract.getItemIdStaking(_itemId);
        
        require(_sellerAddress == msg.sender, "Invalid sender or seller address");

        if(
            keccak256(abi.encodePacked(_itemState)) == keccak256(abi.encodePacked("Sold")) || keccak256(abi.encodePacked(_itemState)) == keccak256(abi.encodePacked("Deleted"))
        ) {

            SellStake storage _stake = sellStakes[_stakeId];

            require(_sellerAddress == _stake.user, "Invalid sender or seller address");

            require(_stake.state != State.Withdrawed, "Already withdrawed");

            (bool sent, bytes memory data) = _stake.user.call{value: _stake.amount}("");
            require(sent, "Failed to send Ether");

            _stake.state = State.Withdrawed;

            sellStakesOfSeller[_sellerAddress][_stake.sellStakesOfSellerIndex].state = State.Withdrawed;

            emit SellStakeRefunded(_itemId, _stake.amount, msg.sender, block.timestamp);

            return true;

        } else {
            return false;
        }
    }

    function refundStakeToBuyer(uint _orderId, uint _stakeId) external returns(bool) {
        (uint orderId, uint _amount, string memory  _orderState, address _buyerAddress) = _orderContract.getOrderIdStaking(_orderId);

        // Check sender address
        require(_buyerAddress == msg.sender, "Invalid buyer address");
        if(
              (keccak256(abi.encodePacked(_orderState)) == keccak256(abi.encodePacked("Cancelled"))) || (keccak256(abi.encodePacked(_orderState)) == keccak256(abi.encodePacked("Delivered")))
        ) {
            
            BuyStake storage _stake = buyStakes[_stakeId];

            require(_buyerAddress == _stake.user, "Invalid sender or seller address");

            require(_stake.state != State.Withdrawed, "Already withdrawed");

            (bool sent, bytes memory data) = _stake.user.call{value: _stake.amount}("");
            require(sent, "Failed to send Ether");

            _stake.state = State.Withdrawed;

            buyStakesOfBuyer[_buyerAddress][_stake.buyStakesOfBuyerIndex].state = State.Withdrawed;

            emit BuyStakeRefunded(_orderId, _stake.amount, msg.sender, block.timestamp);
            
            return true;
        } else {
            return false;
        }

    }
    function refundStakeToBuyerBySeller(uint _orderId, address _buyerAddress) external onlyCaller returns (bool) {

            uint _stakeId = sellStakesIdOrderId[_orderId];

            BuyStake storage _stake = buyStakes[_stakeId];

            require(_stake.state != State.Withdrawed, "Already withdrawed");

            (bool sent, bytes memory data) = _stake.user.call{value: _stake.amount}("");
            require(sent, "Failed to send Ether");

            _stake.state = State.Withdrawed;

            buyStakesOfBuyer[_buyerAddress][_stake.buyStakesOfBuyerIndex].state = State.Withdrawed;

            emit BuyStakeRefunded(_orderId, _stake.amount, _buyerAddress, block.timestamp);

            return true;
    }
}

