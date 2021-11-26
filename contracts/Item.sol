// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/access/Ownable.sol";



contract Item is Ownable, AccessControl{
    using Counters for Counters.Counter;
    
    bytes32 public constant CALLERS = keccak256("CALLER");

    enum State {Active, Deactivated, PendStatke, Deleted, Sold}

    Counters.Counter public itemCount;
    
    struct ItemStruct {
        uint Id;
        string title;
        uint price;
        State state;
        string description;
        uint256 createdAt;
        address payable sellerAddress;
        string sellerLocation;
        string sellerEmail;
        bytes sellerPublicKey;
        bytes pictureIPFSHash;
        uint itemesOfAddressArray;
    }

    mapping(uint => ItemStruct) public items;

    mapping(address => ItemStruct[]) public itemesOfAddress;

    event ItemAdded(uint itemId, string title, State state,  address seller);

    modifier onlyCaller() {
        require(hasRole(CALLERS, msg.sender), "Not Allowed to call this function");
        _;
    }

    modifier onlySeller(uint _itemId) {
        require(items[_itemId].sellerAddress != msg.sender, "You are not the seller and not allowed");
        _;
    }

    function addRoles(address _address) public onlyOwner {
          _setupRole(CALLERS, _address);
    }
    
    function addItem(
        string memory _title,
        uint _price,
        string memory _description,
        string memory _location,
        string memory _email,
        bytes memory _publicKey,
        bytes memory _pictureHash
      ) public returns (bool) {

        require(bytes(_title).length > 40, "Title length can not be more than 40 chracters");
        require(bytes(_description).length > 350, "Description length can not be more than 350 chracters");
        require(bytes(_location).length > 50, "Location length can not be more than 50 chracters");
        // Should validate email
        require(bytes(_publicKey).length != 128, "Public key length can not be more than 128 chracters");
        require(bytes(_pictureHash).length != 48, "Location length can not be more than 48 chracters");

        ItemStruct memory _item = ItemStruct({
        Id: itemCount.current(),
        title: _title,
        price: _price, 
        state: State.PendStatke, 
        description: _description,
        createdAt: block.timestamp,
        sellerAddress: payable(msg.sender), 
        sellerLocation: _location,
        sellerEmail: _email,
        sellerPublicKey: _publicKey,
        pictureIPFSHash: _pictureHash,
        itemesOfAddressArray: itemesOfAddress[msg.sender].length
        });
        
        items[itemCount.current()] = _item;

        itemCount.increment();

        itemesOfAddress[msg.sender].push(_item);

        emit ItemAdded(itemCount.current() - 1, _item.title, _item.state, _item.sellerAddress);

        return true;
  }

    function fetchItem(uint _itemId) public view
     returns (string memory name, uint price, uint state, address seller, string memory _email, bytes memory _publicKey)
      {
        return (
                items[_itemId].title,
                items[_itemId].price,
                uint(items[_itemId].state),
                items[_itemId].sellerAddress,
                items[_itemId].sellerEmail,
                items[_itemId].sellerPublicKey
            );
       }

    function getItemIdStaking(uint _itemId) external view onlyCaller
     returns (uint itemId, uint price, string memory state, address seller, string memory sellerEmail, bytes memory sellerPublicKey)
      { 
        string memory itemState;

        ItemStruct memory _item = items[_itemId];

        // For check if item exist or not with address default value
        require(_item.sellerAddress == address(0), "Item Not Found");

        if (_item.state == State.PendStatke) {
            itemState = "Pending Stake";
        } else if (_item.state == State.Active) {
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

        if (keccak256(abi.encodePacked("Pending Stake")) == keccak256(abi.encodePacked(_state))) {
            itemState = State.PendStatke;
        } else if (keccak256(abi.encodePacked("Active")) == keccak256(abi.encodePacked(_state))) {
            require(_item.state == State.Deleted, "You can not Activate a deleted post");

            itemState = State.Active;
        } else if (keccak256(abi.encodePacked("Sold")) == keccak256(abi.encodePacked(_state))) {
            itemState = State.Sold;

        } else if (keccak256(abi.encodePacked("Deactivated")) == keccak256(abi.encodePacked(_state))) {
            itemState = State.Deactivated;
        } else {
            revert("Invalid State");
        }

        _item.state = itemState;

        itemesOfAddress[msg.sender][_item.itemesOfAddressArray].state = itemState;

        return (true);
     }
    
    function deleteItemBySeller(uint _itemId) external onlySeller(_itemId)
      returns (bool)
      { 
        ItemStruct storage _item = items[_itemId];

        require(_item.state != State.Active, "You can not delete this item");

        _item.state = State.Deleted;

        itemesOfAddress[msg.sender][_item.itemesOfAddressArray].state = State.Deleted;

        return (true);
     }
}

