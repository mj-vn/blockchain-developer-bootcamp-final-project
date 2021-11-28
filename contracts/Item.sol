// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "./Stake.sol";

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract Item is Ownable, AccessControl{
    using Counters for Counters.Counter;
    
    bytes32 public constant CALLERS = keccak256("CALLER");

    enum State {Active, Deactivated, Deleted, Sold}

    Counters.Counter public itemCount;

    Stake public _stakeContract;
    
    struct ItemStruct {
        uint Id;
        string title;
        uint price;
        State state;
        string description;
        address payable sellerAddress;
        string sellerCountry;
        string sellerEmail;
        string sellerPublicKey;
        string pictureIPFSHash;
        uint itemesOfAddressArray;
        uint itemssArrayIndex;
    }

    ItemStruct[] public itemsArray;
    mapping(uint => ItemStruct) public items;

    mapping(address => ItemStruct[]) public itemesOfAddress;

    event ItemAdded(uint indexed itemId, string title, State state,  address seller, string city);

    modifier onlyCaller() {
        require(hasRole(CALLERS, msg.sender), "Not Allowed to call this function");
        _;
    }

    modifier onlySeller(uint _itemId) {
        require(items[_itemId].sellerAddress == msg.sender, "You are not the seller and not allowed");
        _;
    }

    constructor(Stake _addressStake) {
        _stakeContract = _addressStake;
    }

    function addRoles(address _address) public onlyOwner {
          _setupRole(CALLERS, _address);
    }
    
    function addItem(
        string memory _title,
        uint _price,
        string memory _description,
        string memory _country,
        string memory _city,
        string memory _email,
        string memory _publicKey,
        string memory _pictureHash
      ) public payable returns (bool) {

        require(bytes(_title).length < 40, "Title length can not be more than 40 chracters");
        require(bytes(_description).length < 350, "Description length can not be more than 350 chracters");
        require(bytes(_country).length < 20, "Country length can not be more than 20 chracters");
        require(bytes(_country).length < 20, "Country length can not be more than 20 chracters");
        // Should validate email
        require(bytes(_publicKey).length == 44, "Public key length can not be more than 44 chracters");
        require(bytes(_pictureHash).length == 46, "Location length can not be more than 46 chracters");
        require(_price == msg.value, "Not Enough Ether value to be staked");

        ItemStruct memory _item = ItemStruct({
        Id: itemCount.current(),
        title: _title,
        price: _price, 
        state: State.Active, 
        description: _description,
        sellerAddress: payable(msg.sender),
        sellerCountry: _country,
        sellerEmail: _email,
        sellerPublicKey: _publicKey,
        pictureIPFSHash: _pictureHash,
        itemesOfAddressArray: itemesOfAddress[msg.sender].length,
        itemssArrayIndex: itemsArray.length
        });
        
        items[itemCount.current()] = _item;

        itemCount.increment();

        itemesOfAddress[msg.sender].push(_item);
        itemsArray.push(_item);
        _stakeContract._stakeForItem{value: msg.value}(_item.Id, msg.sender);

        emit ItemAdded(itemCount.current() - 1, _item.title, _item.state, _item.sellerAddress, _city);

        return true;
  }

    function fetchItem(uint _itemId) external view
     returns (
        string memory name,
        uint price,
        uint state,
        address seller,
        string memory _email,
        string memory _publicKey,
        string memory _pictureHash, 
        string memory _country
    )
      {
        ItemStruct memory _item = items[_itemId];

        return (
                _item.title,
                _item.price,
                uint(_item.state),
                _item.sellerAddress,
                _item.sellerEmail,
                _item.sellerPublicKey,
                _item.pictureIPFSHash,
                _item.sellerCountry
            );
       }

    function getItemForOrder(uint _itemId) external view onlyCaller
     returns (uint itemId, uint price, string memory state, address seller, string memory sellerEmail, string memory sellerPublicKey)
      { 
        string memory itemState;

        ItemStruct memory _item = items[_itemId];

        // For check if item exist or not with address default value
        require(_item.sellerAddress != address(0), "Item Not Found");

        if (_item.state == State.Active) {
            itemState = "Active";
        } else if (_item.state == State.Deleted) {
            itemState = "Deleted";
        } else if (_item.state == State.Sold) {
            itemState = "Sold";
        } else {
            itemState = "Deactivated";
        }

        return (_itemId, _item.price, itemState, _item.sellerAddress, _item.sellerEmail, _item.sellerPublicKey);
     }
      
    function updateItemState(uint _itemId, string memory _state) external onlyCaller
     returns (bool)
      { 
        State itemState;

        ItemStruct storage _item = items[_itemId];

        if (keccak256(abi.encodePacked("Active")) == keccak256(abi.encodePacked(_state))) {
            require(_item.state != State.Deleted, "You can not Activate a deleted post");

            itemState = State.Active;
        } else if (keccak256(abi.encodePacked("Sold")) == keccak256(abi.encodePacked(_state))) {
            itemState = State.Sold;

        } else if (keccak256(abi.encodePacked("Deactivated")) == keccak256(abi.encodePacked(_state))) {
            itemState = State.Deactivated;

        } else {
            revert("Invalid State");
        }

        _item.state = itemState;

        itemesOfAddress[_item.sellerAddress][_item.itemesOfAddressArray].state = itemState;
        itemsArray[_item.itemssArrayIndex].state = State.Deleted;

        return (true);
     }
    
    function deleteItemBySeller(uint _itemId) external onlySeller(_itemId)
      returns (bool)
      { 
        ItemStruct storage _item = items[_itemId];

        require(_item.state == State.Active, "You can not delete this item");

        _item.state = State.Deleted;

        itemesOfAddress[msg.sender][_item.itemesOfAddressArray].state = State.Deleted;
        itemsArray[_item.itemssArrayIndex].state = State.Deleted;

        return (true);
    }

    function fetchPageDescending(uint cursor, uint howMany)
    external
    view
    returns (ItemStruct[] memory values, int newCursor, uint length)
    {
        uint length = howMany;
        if (length > itemsArray.length + cursor) {
            length = itemsArray.length + cursor;
        }

        ItemStruct[] memory values = new ItemStruct[](length);
        for (uint i = 0; i < length; i++) {
            if (cursor >= i){
                values[i] = itemsArray[cursor - i];
            } else {
                break;
            }
        }

        // uint memory _newCursor;

        return (values, int(int(cursor) - int(length)), length);
    }
    function fetchPageAscending(uint cursor, uint howMany)
    external
    view
    returns (ItemStruct[] memory values, uint newCursor)
    {
        uint length = howMany;
        if (length > itemsArray.length - cursor) {
            length = itemsArray.length - cursor;
        }

        ItemStruct[] memory values = new ItemStruct[](length);
        for (uint i = 0; i < length; i++) {
            values[i] = itemsArray[cursor + i];
        }

        return (values, cursor + length);
    }

    function getItemsArrayLength()
    external
    view
    returns (uint length)
    {
        return (itemsArray.length);
    }
}

