// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "./Stake.sol";

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract Escrow is Ownable, AccessControl{
    using Counters for Counters.Counter;

    bytes32 public constant CALLERS = keccak256("CALLER");

    Stake public _stakeContract;
    
    enum State {Deposited, Withdrawed}

    Counters.Counter public escrowCount;
    
    struct EscrowStruct {
        uint orderId;
        uint amount;
        State state;
        uint createdAt;
        address payable sellerAddress;
        address payable buyerAddress;
    }

    mapping(uint => EscrowStruct) public escrows;

    mapping(address => mapping(uint => EscrowStruct)) public escrowOfBuyer;

    mapping(address => mapping(uint => EscrowStruct)) public escrowOfSeller;

    event EscrowDeposited(uint escrowId, uint orderId, uint amount, address sellerAddress, address buyerAddress, uint createdAt);

    event EscrowRefunded(uint escrowId, uint orderId, uint amount, address sellerAddress, address buyerAddress, uint createdAt);

    event EscrowWithdrawed(uint escrowId, uint orderId, uint amount, address sellerAddress, address buyerAddress, uint createdAt);

    modifier onlyCaller() {
        require(hasRole(CALLERS, msg.sender), "Not Allowed to call this function");
        _;
    }

    constructor(Stake _addressStake) {
        _stakeContract = _addressStake;
    }

    function addRoles(address _address) public onlyOwner {
          _setupRole(CALLERS, _address);
    }
    
    function depositEscrow (
        uint _orderId,
        address _sellerAddress,
        address _buyerAddress
      ) external payable onlyCaller returns (bool) {

        EscrowStruct memory _escrow = EscrowStruct({
        orderId: _orderId,
        amount: msg.value,
        state: State.Deposited,
        createdAt: block.timestamp,
        sellerAddress: payable(_sellerAddress),
        buyerAddress: payable(_buyerAddress)
        });
        
        escrows[escrowCount.current()] = _escrow;

        escrowCount.increment();

        escrowOfBuyer[msg.sender][_orderId] = _escrow ;
        escrowOfSeller[msg.sender][_orderId] = _escrow ;

        emit EscrowDeposited(escrowCount.current() - 1, _orderId, msg.value, _sellerAddress, _buyerAddress, block.timestamp);

        return true;
    }

    function refundEscrowToBuyer (
        uint _orderId,
        address _buyerAddress
      ) external onlyCaller returns (bool) {

        EscrowStruct storage _escrow = escrowOfBuyer[_buyerAddress][_orderId];

        require(_escrow.state == State.Withdrawed, "Already withdrawed");

        (bool sent, bytes memory data) = _escrow.buyerAddress.call{value: _escrow.amount }("");
        require(sent, "Failed to send Ether");

        _escrow.state = State.Withdrawed;
        _stakeContract.refundStakeToBuyerBySeller(_orderId, _buyerAddress);

        emit EscrowRefunded(escrowCount.current() - 1, _orderId, _escrow.amount, _escrow.sellerAddress, _buyerAddress, block.timestamp);

        return true;
  }

    function withdrawEscrowToSeller (
        uint _orderId,
        address _sellerAddress
      ) external onlyCaller returns (bool) {

        EscrowStruct storage _escrow = escrowOfSeller[_sellerAddress][_orderId];

        require(_escrow.state == State.Withdrawed, "Already withdrawed");

        (bool sent, bytes memory data) = _escrow.sellerAddress.call{value: _escrow.amount}("");
        require(sent, "Failed to send Ether");

        _escrow.state = State.Withdrawed;

        emit EscrowWithdrawed(escrowCount.current() - 1, _orderId, _escrow.amount, _escrow.sellerAddress, _escrow.buyerAddress, block.timestamp);

        return true;
  }

}