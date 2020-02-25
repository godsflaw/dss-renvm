pragma solidity ^0.5.12;

interface IERC20 {
    function balanceOf   (address)                external view returns (uint256);
    function approve     (address, uint256)       external returns (bool);
    function transferFrom(address, address, uint) external returns (bool);
    function transfer    (address, uint256)       external returns (bool);
}

contract GemJoin {
    function join(address, uint) public;
    function exit(address, uint) public;
}

contract CdpManager {
    function open(bytes32, address) external returns (uint);
    function frob(uint, int, int) external;
    function move(uint, address, uint) external;
    function flux(uint, address, uint) external;
    function urns(uint) view external returns (address);
}

contract Vat {
    function hope(address usr) external;
}

contract DirectZBTCProxy {

    uint256 constant RAY  = 10 ** 27; // This is what MakerDAO uses.
    uint256 constant NORM = 10 ** 10; // This is the difference between 18
                                      // decimals in ERC20s and 8 in BTC
                                      // TODO: fix if we make more generic

    IERC20 public zbtc; // zBTC.
    IERC20 public dai;  // Dai.

    bytes32    public ilk;
    CdpManager public manager;
    GemJoin    public daiGemJoin;
    GemJoin    public zbtcGemJoin;
    Vat        public daiVat;

    mapping (address => mapping(address => uint256)) cdpids;

    constructor(
        address _zbtc,
        address _dai,

        bytes32 _ilk,
        address _manager,
        address _daiGemJoin,
        address _zbtcGemJoin,
        address _daiVat
    ) public {
        zbtc = IERC20(_zbtc);  // TODO: perhaps we can make this more generic
        dai  = IERC20(_dai);

        ilk         = _ilk;
        manager     = CdpManager(_manager);
        daiGemJoin  = GemJoin(_daiGemJoin);
        zbtcGemJoin = GemJoin(_zbtcGemJoin);
        daiVat      = Vat(_daiVat);

        daiVat.hope(address(daiGemJoin));
        require(zbtc.approve(_zbtcGemJoin, uint(-1)), "err: approve zBTC");
        require(dai.approve(_daiGemJoin, uint(-1)), "err approve: dai");
    }

    function borrow(
        address _owner, // CDP owner (if CDP doesn't exist one will be created)
        int     _dink,  // Amount of zBTC to collateralize (18 decimals)
        int     _dart   // Amount of Dai to borrow (18 decimals)
    ) external {
        require(_owner != address(this), "err: self-reference");
        require(_dink >= 0, "err: negative dink");
        require(_dart >= 0, "err: negative dart");

        // Create CDP
        uint256 cdpid = cdpids[msg.sender][_owner];
        if (cdpid == 0) {
            cdpid = manager.open(ilk, address(this));
            cdpids[msg.sender][_owner] = cdpid;
        }

        zbtcGemJoin.join(manager.urns(cdpid), uint(_dink)/NORM);

        manager.frob(cdpid, _dink, _dart);
        manager.move(cdpid, address(this), uint(_dart) * RAY);
        daiGemJoin.exit(_owner, uint(_dart));
    }

    function repay(
        address _owner, // CDP owner
        int     _dink,  // Amount of zBTC to reclaim (with 18 decimal places).
        int     _dart   // Amount of Dai to repay
    ) external {
        require(_owner != address(this), "err: self-reference");
        require(_dink >= 0, "err: negative dink");
        require(_dart >= 0, "err: negative dart");

        uint256 cdpid = cdpids[msg.sender][_owner];
        require(cdpid != 0, "err: vault not found");

        // Join Dai into the gem
        daiGemJoin.join(manager.urns(cdpid), uint(_dart));

        // Lower the debt and exit some collateral
        manager.frob(cdpid, -_dink, -_dart);
        manager.flux(cdpid, address(this), uint(_dink));
        zbtcGemJoin.exit(address(this), uint(_dink)/NORM);

        // Send reclaimed collateral to the msg.sender.
        zbtc.transfer(msg.sender, uint(_dink)/NORM);
    }
}
