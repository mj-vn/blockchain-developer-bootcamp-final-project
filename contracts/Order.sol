// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "./Item.sol";
import "./Escrow.sol";
import "./Stake.sol";

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract Order is Ownable, AccessControl{
    using Counters for Counters.Counter;

    Item public _itemContract;
    Escrow public _escrowContract;
    Stake public _stakeContract;
    
    bytes32 public constant CALLERS = keccak256("CALLER");

    enum State {Confirmed, Cancelled, PendConfirm, Posted, Delivered}

    Counters.Counter public orderCount;
    
    struct OrderStruct {
        uint Id;
        uint itemId;
        uint amount;
        State state;
        uint256 createdAt;
        address payable sellerAddress;
        address payable buyerAddress;
        string buyerEmail;
        string sellerEmail;
        uint orderOfBuyerIndex;
        uint orderOfSellerIndex;
    }

    mapping(uint => OrderStruct) public orders;

    mapping(address => OrderStruct[]) public orderOfBuyer;

    mapping(address => OrderStruct[]) public orderOfSeller;

    event OrderAdded(uint indexed orderId, uint itemId, uint amount, address sellerAddress, address buyerAddress, string buyerLocation);
    event OrderUpdatedBySeller(uint orderId, address sellerAddress, address buyerAddress, State _toState);

    event OrderDeliveryConfirmed(uint orderId, address sellerAddress, address buyerAddress, uint deliveryTime);

    event OrderAdded2(uint value);
    
    event calledUpdateItemState(uint value);

    event calledStake(uint value);

    event calledEscrow(uint value);

    modifier onlyCaller() {
        require(hasRole(CALLERS, msg.sender), "Not Allowed to call this function");
        _;
    }

    modifier onlySeller(uint _orderId) {
        require(orders[_orderId].sellerAddress == msg.sender, "You are not the seller and not allowed");
        _;
    }

    modifier onlyBuyer(uint _orderId) {
        require(orders[_orderId].buyerAddress == msg.sender, "You are not the buyer and not allowed");
        _;
    }

    constructor(Item _addressItem, Escrow _addressEscrow, Stake _addressStake) {
        _itemContract = _addressItem;
        _escrowContract = _addressEscrow;
        _stakeContract = _addressStake;
    }
    
    function addRoles(address _address) public onlyOwner {
          _setupRole(CALLERS, _address);
    }

    function addOrder(
        uint _itemId,
        string memory _buyerEmail,
        string memory _buyerLocationAddress
      ) public payable returns (bool) {
        (
            uint _itemIdGet,
            uint  _price,
            string memory  _itemState,
            address _sellerAddress,
            string memory  _sellerEmail,
            // Think Abount Use the below varivale
            string memory _itemPublicKey
        ) = _itemContract.getItemForOrder(_itemId);

        require(keccak256(abi.encodePacked(_itemState)) == keccak256(abi.encodePacked("Active")), "Item is not available");
        require((_price * 2) == msg.value, "Invalid amount to be deposited");
        
        require(bytes(_buyerLocationAddress).length < 1100, "Address Should be smaller than 1100 chrachter");

        OrderStruct memory _order = OrderStruct({
        Id: orderCount.current(),
        itemId: _itemIdGet,
        amount: _price,
        state: State.PendConfirm,
        createdAt: block.timestamp,
        sellerAddress: payable(_sellerAddress),
        buyerAddress: payable(msg.sender),
        buyerEmail: _buyerEmail,
        sellerEmail: _sellerEmail,
        orderOfBuyerIndex: orderOfBuyer[msg.sender].length,
        orderOfSellerIndex: orderOfSeller[_sellerAddress].length 
        });
        
        orders[orderCount.current()] = _order;

        orderCount.increment();

        orderOfBuyer[msg.sender].push(_order);
        orderOfSeller[_sellerAddress].push(_order);

        emit OrderAdded2(_order.amount);


       _itemContract.updateItemState(_itemId, "Deactivated");
       emit calledUpdateItemState(_order.amount);

       _stakeContract._stakeForOrder{value: msg.value - _price}(_order.Id, msg.sender);
        emit calledStake(msg.value - _price);

       _escrowContract.depositEscrow{value: msg.value - _price}(orderCount.current() - 1, _sellerAddress, msg.sender);
        emit calledEscrow(msg.value - _price);


        emit OrderAdded(orderCount.current() - 1, _itemIdGet, _price, _sellerAddress, msg.sender, _buyerLocationAddress);

        return true;
  }

    function updateOrderBySeller(uint _orderId, string memory _state) external onlySeller(_orderId)
        returns (bool)
      { 
        State  orderState;

        OrderStruct storage _order = orders[_orderId];

        // For check if order exist or not with address default value
        require(_order.sellerAddress != address(0), "Order Not Found");

        if (keccak256(abi.encodePacked("Confirmed")) == keccak256(abi.encodePacked(_state))) {
            orderState = State.Confirmed;

        } else if (keccak256(abi.encodePacked("Posted")) == keccak256(abi.encodePacked(_state))) {
            orderState = State.Posted;

        } else if (keccak256(abi.encodePacked("Cancelled")) == keccak256(abi.encodePacked(_state))) {
            orderState = State.Cancelled;
            _itemContract.updateItemState(_order.itemId, "Active");
            _escrowContract.refundEscrowToBuyer(_orderId, _order.buyerAddress);
            _stakeContract.refundStakeToBuyer(_orderId, _order.buyerAddress);

        } else {
            revert("Invalid State");
        }

        _order.state = orderState;

        orderOfSeller[_order.sellerAddress][_order.orderOfSellerIndex].state = orderState;

        orderOfBuyer[_order.buyerAddress][_order.orderOfBuyerIndex].state = orderState;

        emit OrderUpdatedBySeller(_orderId, _order.sellerAddress, _order.buyerAddress, orderState);

        return (true);
     }

    function confirmOrderDeliveryByBuyer(uint _orderId) public onlyBuyer(_orderId)
        returns (bool)
      {
        OrderStruct storage _order = orders[_orderId];

        // For check if order exist or not with address default value
        require(_order.sellerAddress != address(0), "Order Not Found");

        _order.state = State.Delivered;

        orderOfSeller[_order.sellerAddress][_order.orderOfSellerIndex].state = State.Delivered;

        orderOfBuyer[_order.buyerAddress][_order.orderOfBuyerIndex].state = State.Delivered;

        _escrowContract.withdrawEscrowToSeller(_orderId, _order.sellerAddress);
        _itemContract.updateItemState(_order.itemId, "Sold");
        _stakeContract.refundStakeToBuyer(_orderId, _order.buyerAddress);
        _stakeContract.refundStakeToSeller(_orderId, _order.sellerAddress);


        emit OrderDeliveryConfirmed(_orderId, _order.sellerAddress, _order.buyerAddress, block.timestamp);

        return (true);
    }
}

