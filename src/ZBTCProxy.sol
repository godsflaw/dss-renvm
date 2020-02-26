pragma solidity ^0.5.12;

interface IERC20 {
    function balanceOf   (address)                external view returns (uint256);
    function approve     (address, uint256)       external      returns (bool);
    function transferFrom(address, address, uint) external      returns (bool);
    function transfer    (address, uint256)       external      returns (bool);
}

interface IShifter {
    function shiftIn (bytes32 _pHash, uint256 _amount, bytes32 _nHash, bytes calldata _sig) external returns (uint256);
    function shiftOut(bytes calldata _to, uint256 _amount) external returns (uint256);
}

interface IShifterRegistry {
    function getShifterBySymbol(string calldata _tokenSymbol) external view returns (IShifter);
    function getTokenBySymbol  (string calldata _tokenSymbol) external view returns (IERC20);
}

contract DirectZBTCProxy {

    function borrow(
        address _owner, // CDP owner (if they do not own a CDP, one will be created).
        int     _dink,  // Amount of zBTC to collateralize (18 decimals).
        int     _dart   // Amount of Dai to borrow (18 decimals).
    ) external;

    function repay(
        address _owner, // CDP owner
        int     _dink,  // Amount of zBTC to reclaim (with 18 decimal places).
        int     _dart   // Amount of Dai to repay
    ) external;
}

contract ZBTCProxy {

    IShifterRegistry public registry;
    IERC20           public dai;
    DirectZBTCProxy  public directProxy;

    mapping (address => bytes) public btcAddrs;

    constructor(
        address _registry,
        address _dai,
        address _directProxy
    ) public {
        registry    = IShifterRegistry(_registry);
        dai         = IERC20(_dai);
        directProxy = DirectZBTCProxy(_directProxy);
    }

    // TODO: test me
    function mintDai(
        // User params
        int     _dart,
        bytes calldata _btcAddr,

        // Darknode params
        uint256        _amount, // Amount of zBTC.
        bytes32        _nHash,  // Nonce hash.
        bytes calldata _sig     // Minting signature. TODO: understand better
    ) external {
        // Finish the lock-and-mint cross-chain transaction using the minting
        // signature produced by RenVM.
        bytes32 pHash = keccak256(abi.encode(msg.sender, _dart, _btcAddr));
        // TODO: read the IShifter code
        uint256 amount = IShifter(registry.getShifterBySymbol("zBTC"))
            .shiftIn(pHash, _amount, _nHash, _sig);

        require(
            IERC20(registry.getTokenBySymbol("zBTC"))
                .transfer(address(directProxy), amount),
            "err: transfer failed"
        );

        directProxy.borrow(
            msg.sender,
            int(amount * (10 ** 10)),
            _dart
        );

        btcAddrs[msg.sender] = _btcAddr;
    }

    // TODO: test me
    function burnDai(
        // User params
        uint256 _dink,  // Amount of zBTC (with  8 decimal places)
        uint256 _dart   // Amount of DAI  (with 18 decimal places)
    ) external {
        // get DAI from the msg.sender (requires msg.sender to approve)
        require(
            dai.transferFrom(msg.sender, address(this), _dart),
            "err: transferFrom dai"
        );

        // send DAI to the directProxy
        require(
            dai.transfer(address(directProxy), _dart),
            "err: transfer dai"
        );

        // proxy through to the direct proxy.
        directProxy.repay(
            msg.sender,
            int(_dink) * (10 ** 10),
            int(_dart)
        );

        // Initiate the burn-and-release cross-chain transaction,
        // after which RenVM will finish the cross-chain
        // transaction by releasing BTC to the specified to address.
        // TODO: consider rewriting how we get the shifter (constructor)
        registry
            .getShifterBySymbol("zBTC")
            .shiftOut(btcAddrs[msg.sender], _dink);
    }
}
