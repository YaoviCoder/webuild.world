 // solhint-disable-next-line compiler-fixed, compiler-gt-0_4
pragma solidity ^0.4.23;

import "zeppelin-solidity/contracts/math/SafeMath.sol";
import "zeppelin-solidity/contracts/ownership/Ownable.sol";
import "./libs/Dictionary.sol";
import "./Provider.sol";


contract WeBuildWorldImplementation is Ownable, Provider {
    using SafeMath for uint256;	
    using Dictionary for Dictionary.Data;

    enum BrickStatus { Inactive, Active, Completed, Cancelled }

    struct Builder {
        address addr;
        uint dateAdded;
        bytes32 key;
        bytes32 nickName;
    }
    
    struct Brick {
        string title;
        string url;
        string description;
        bytes32[] tags;
        address owner;
        uint value;
        uint32 dateCreated;
        uint32 dateCompleted;
        uint32 expired;
        uint32 numBuilders;
        BrickStatus status;
        address[] winners;
        mapping (uint => Builder) builders;
    }

    address public main = 0x0;
    mapping (uint => Brick) public bricks;

    string public constant VERSION = "0.1";
    Dictionary.Data public brickIds;
    uint public constant DENOMINATOR = 10000;

    modifier onlyMain() {
        require(msg.sender == main);
        _;
    }

    function () public payable {
        revert();
    }    

    function isBrickOwner(uint _brickId, address _address) external view returns (bool success) {
        return bricks[_brickId].owner == _address;
    }    

    function addBrick(uint _brickId, string _title, string _url, uint _expired, string _description, bytes32[] _tags, uint _value) 
        external onlyMain
        returns (bool success)
    {
        // greater than 0.01 eth
        require(_value >= 10 ** 16);
        // solhint-disable-next-line
        require(bricks[_brickId].owner == 0x0 || bricks[_brickId].owner == tx.origin);

        Brick memory brick = Brick({
            title: _title,
            url: _url,
            description: _description,   
            tags: _tags,
            // solhint-disable-next-line
            owner: tx.origin,
            status: BrickStatus.Active,
            value: _value,
            // solhint-disable-next-line 
            dateCreated: uint32(now),
            dateCompleted: 0,
            expired: uint32(_expired),
            numBuilders: 0,
            winners: new address[](0)
        });

        // only add when it's new
        if (bricks[_brickId].owner == 0x0) {
            brickIds.insertBeginning(_brickId, 0);
        }
        bricks[_brickId] = brick;

        return true;
    }

    function changeBrick(uint _brickId, string _title, string _url, string _description, bytes32[] _tags, uint _value) 
        external onlyMain
        returns (bool success) 
    {
        require(bricks[_brickId].status == BrickStatus.Active);

        bricks[_brickId].title = _title;
        bricks[_brickId].url = _url;
        bricks[_brickId].description = _description;
        bricks[_brickId].tags = _tags;

        // Add to the fund.
        if (_value > 0) {
            bricks[_brickId].value = bricks[_brickId].value.add(_value);
        }

        return true;
    }

    // msg.value is tip.
    function accept(uint _brickId, address[] _winners, uint[] _weights, uint _value) 
        external onlyMain
        returns (uint) 
    {
        require(bricks[_brickId].status == BrickStatus.Active);
        require(_winners.length == _weights.length);
        // disallow to take to your own.

        uint total = 0;
        bool included = false;
        for (uint i = 0; i < _winners.length; i++) {
            // solhint-disable-next-line
            require(_winners[i] != tx.origin, "Owner should not win this himself");
            for (uint j =0; j < bricks[_brickId].numBuilders; j++) {
                if (bricks[_brickId].builders[j].addr == _winners[i]) {
                    included = true;
                    break;
                }
            }
            total = total.add(_weights[i]);
        }

        require(included, "Winner doesn't participant");
        require(total == DENOMINATOR, "total should be in total equals to denominator");

        bricks[_brickId].status = BrickStatus.Completed;
        bricks[_brickId].winners = _winners;
        // solhint-disable-next-line
        bricks[_brickId].dateCompleted = uint32(now);

        if (_value > 0) {
            bricks[_brickId].value = bricks[_brickId].value.add(_value);
        }

        return bricks[_brickId].value;
    }

    function cancel(uint _brickId) 
        external onlyMain
        returns (uint value) 
    {
        require(bricks[_brickId].status != BrickStatus.Completed);
        require(bricks[_brickId].status != BrickStatus.Cancelled);

        bricks[_brickId].status = BrickStatus.Cancelled;

        return bricks[_brickId].value;
    }

    function startWork(uint _brickId, bytes32 _builderId, bytes32 _nickName, address _builderAddress) 
        external onlyMain returns(bool success)
    {
        require(_builderAddress != 0x0);
        require(bricks[_brickId].status == BrickStatus.Active);
        require(_brickId >= 0);
        require(bricks[_brickId].expired >= now);

        bool included = false;

        for (uint i = 0; i < bricks[_brickId].numBuilders; i++) {
            if (bricks[_brickId].builders[i].addr == _builderAddress) {
                included = true;
                break;
            }
        }
        require(!included);

        // bricks[_brickId]
        Builder memory builder = Builder({
            addr: _builderAddress,
            key: _builderId,
            nickName: _nickName,
            // solhint-disable-next-line
            dateAdded: now
        });
        bricks[_brickId].builders[bricks[_brickId].numBuilders++] = builder;

        return true;
    }

    function getBrickIds() external view returns(uint[]) {
        return brickIds.keys();
    }    

    function getBrickSize() external view returns(uint) {
        return brickIds.getSize();
    }

    function _matchedTags(bytes32[] _tags, bytes32[] _stack) private pure returns (bool){
        if(_tags.length > 0){
            for (uint i = 0; i < _tags.length; i++) {
                for(uint j = 0; j < _stack.length; j++){
                    if(_tags[i] == _stack[j]){
                        return true;
                    }
                }
            }
            return false;
        }else{
            return true;
        } 
    }

    function participated(
        uint _brickId,   
        address _builder
        )
        external view returns (bool) {
 
        for (uint j = 0; j < bricks[_brickId].numBuilders; j++) {
            if (bricks[_brickId].builders[j].addr == _builder) {
                return true;
            }
        } 

        return false;
    }

    
    function filterBrick(
        uint _brickId, 
        bytes32[] _tags, 
        uint _status, 
        uint _started,
        uint _expired
        )
        external view returns (bool) {  
        Brick memory brick = bricks[_brickId];  

        bool satisfy = _matchedTags(_tags, brick.tags);  

        if(_started > 0){
            satisfy = brick.dateCreated >= _started;
        }
        
        if(_expired > 0){
            satisfy = brick.expired >= _expired;
        }
 
        return satisfy && (uint(brick.status) == _status
            || uint(BrickStatus.Cancelled) < _status 
            || uint(BrickStatus.Inactive) > _status);
    }

    function getBrick(uint _brickId) external view returns (
        string title,
        string url,
        address owner,
        uint value,
        uint32 dateCreated,
        uint32 dateCompleted,
        uint32 expired,
        uint status
    ) {
        Brick memory brick = bricks[_brickId];
        return (
            brick.title,
            brick.url,
            brick.owner,
            brick.value,
            brick.dateCreated,
            brick.dateCompleted,
            brick.expired,
            uint(brick.status)
        );
    }
    
    function getBrickDetail(uint _brickId) external view returns (
        bytes32[] tags,
        string description, 
        uint32 builders,
        address[] winners
    ) {
        Brick memory brick = bricks[_brickId];
        return ( 
            brick.tags, 
            brick.description, 
            brick.numBuilders,
            brick.winners
        );
    }

    function getBrickBuilders(uint _brickId) external view returns (
        address[] addresses,
        uint[] dates,
        bytes32[] keys,
        bytes32[] names
    )
    {
        // Brick memory brick = bricks[_brickId];
        addresses = new address[](bricks[_brickId].numBuilders);
        dates = new uint[](bricks[_brickId].numBuilders);
        keys = new bytes32[](bricks[_brickId].numBuilders);
        names = new bytes32[](bricks[_brickId].numBuilders);

        for (uint i = 0; i < bricks[_brickId].numBuilders; i++) {
            addresses[i] = bricks[_brickId].builders[i].addr;
            dates[i] = bricks[_brickId].builders[i].dateAdded;
            keys[i] = bricks[_brickId].builders[i].key;
            names[i] = bricks[_brickId].builders[i].nickName;
        }
    }    

    function setMain(address _address) public onlyOwner returns(bool) {
        main = _address;
        return true;
    }     
}
