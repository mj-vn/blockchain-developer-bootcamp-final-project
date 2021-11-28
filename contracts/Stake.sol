// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";


contract Stake is Ownable, AccessControl{
    using Counters for Counters.Counter;

    bytes32 public constant CALLERS = keccak256("CALLER");

    Counters.Counter public stakeCount;
    
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

    mapping(uint => uint) public buyStakesIdOrderId;

    mapping(uint => uint) public sellStakesIdItemId;

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

    function addRoles(address _address) public onlyOwner {
          _setupRole(CALLERS, _address);
    }
    
    function _stakeForItem(uint _itemId, address _sellerAddress) external payable onlyCaller returns(bool) {

    SellStake memory _stake = SellStake({
        Id: stakeCount.current(),
        user: payable(_sellerAddress), 
        state: State.Deposited,
        amount: msg.value,
        depositeDate: block.timestamp,  
        itemId: _itemId,
        sellStakesOfSellerIndex: sellStakesOfSeller[_sellerAddress].length
    });

    sellStakes[stakeCount.current()] = _stake;

    sellStakesIdItemId[_itemId] = stakeCount.current();

    stakeCount.increment();

    sellStakesOfSeller[_sellerAddress].push(_stake);

    emit SellStakeDeposited(_itemId, msg.value, _sellerAddress, block.timestamp);

    return true;

    }

    function _stakeForOrder(uint _orderId, address _buyerAddress) external payable onlyCaller returns(bool) {    
        BuyStake memory _stake = BuyStake({
            Id: stakeCount.current(),
            user: payable(_buyerAddress), 
            state: State.Deposited,
            amount: msg.value,
            depositeDate: block.timestamp,  
            orderId: _orderId,
            buyStakesOfBuyerIndex: buyStakesOfBuyer[_buyerAddress].length
        });

        buyStakes[stakeCount.current()] = _stake;

        buyStakesIdOrderId[_orderId] = stakeCount.current();

        stakeCount.increment();

        buyStakesOfBuyer[_buyerAddress].push(_stake);

        emit BuyStakeDeposited(_orderId, msg.value, _buyerAddress, block.timestamp);

        return true;
    }

    function refundStakeToSeller(uint _itemId, address _sellerAddress) external onlyCaller returns(bool) {

        uint _stakeId = sellStakesIdItemId[_itemId];
        
        SellStake storage _stake = sellStakes[_stakeId];

        require(_stake.state != State.Withdrawed, "Already withdrawed");

        (bool sent, bytes memory data) = _stake.user.call{value: _stake.amount}("");
        require(sent, "Failed to send Ether");

        _stake.state = State.Withdrawed;

        sellStakesOfSeller[_sellerAddress][_stake.sellStakesOfSellerIndex].state = State.Withdrawed;

        emit SellStakeRefunded(_itemId, _stake.amount, _sellerAddress, block.timestamp);

        return true;

    }

    function refundStakeToBuyer(uint _orderId, address _buyerAddress) external onlyCaller returns (bool) {

            uint _stakeId = buyStakesIdOrderId[_orderId];

            BuyStake storage _stake = buyStakes[_stakeId];

            require(_stake.state != State.Withdrawed, "Already withdrawed");

            (bool sent, bytes memory data) = _stake.user.call{value: _stake.amount}("");
            require(sent, "Failed to send Ether");

            _stake.state = State.Withdrawed;

            buyStakesOfBuyer[_buyerAddress][_stake.buyStakesOfBuyerIndex].state = State.Withdrawed;

            emit BuyStakeRefunded(_orderId, _stake.amount, _buyerAddress, block.timestamp);

            return true;
    }


    function fetchPageBuyStakes(uint cursor, uint howMany)
    external
    view
    returns (BuyStake[] memory values, uint newCursor)
    {
        require(msg.sender != address(0), "Invalid Addresss");

        uint length = howMany;
        if (length > buyStakesOfBuyer[msg.sender].length - cursor) {
            length = buyStakesOfBuyer[msg.sender].length - cursor;
        }

        BuyStake[] memory values = new BuyStake[](length);
        for (uint i = 0; i < length; i++) {
            values[i] = buyStakesOfBuyer[msg.sender][cursor + i];
        }

        return (values, cursor + length);
    }

    function fetchPageSellStakes(uint cursor, uint howMany)
    external
    view
    returns (SellStake[] memory values, uint newCursor)
    {
        require(msg.sender != address(0), "Invalid Addresss");

        uint length = howMany;
        if (length > sellStakesOfSeller[msg.sender].length - cursor) {
            length = sellStakesOfSeller[msg.sender].length - cursor;
        }

        SellStake[] memory values = new SellStake[](length);
        for (uint i = 0; i < length; i++) {
            values[i] = sellStakesOfSeller[msg.sender][cursor + i];
        }

        return (values, cursor + length);
    }

}

