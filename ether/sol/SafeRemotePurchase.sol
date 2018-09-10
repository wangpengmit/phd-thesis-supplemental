pragma solidity ^0.4.22;

// PW: this way of selling/buying goods is capital heavy because for buying P value of goods both seller and buyer need to commit and lock 2P capital

contract Purchase {
    uint public value;
    address public seller;
    address public buyer;
    enum State { Created, Locked, Inactive }
    State public state;
    uint public sellerCanWithdraw;
    uint public buyerCanWithdraw;

    // Ensure that `msg.value` is an even number.
    // Division will truncate if it is an odd number.
    // Check via multiplication that it wasn't an odd number.
    constructor() public payable {
        seller = msg.sender;
        value = msg.value / 2;
        require((2 * value) == msg.value, "Value has to be even.");
    }

    modifier condition(bool _condition) {
        require(_condition);
        _;
    }

    modifier onlyBuyer() {
        require(
            msg.sender == buyer,
            "Only buyer can call this."
        );
        _;
    }

    modifier onlySeller() {
        require(
            msg.sender == seller,
            "Only seller can call this."
        );
        _;
    }

    modifier inState(State _state) {
        require(
            state == _state,
            "Invalid state."
        );
        _;
    }

    event Aborted();
    event PurchaseConfirmed();
    event ItemReceived();

    /// Abort the purchase and reclaim the ether.
    /// Can only be called by the seller before
    /// the contract is locked.
    function abort()
        public
        onlySeller
        inState(State.Created)
    {
        emit Aborted();
        state = State.Inactive;
        sellCanWithdraw = address(this).balance;
        /* seller.transfer(address(this).balance); */
    }

    /// Confirm the purchase as buyer.
    /// Transaction has to include `2 * value` ether.
    /// The ether will be locked until confirmReceived
    /// is called.
    function confirmPurchase()
        public
        inState(State.Created)
        condition(msg.value == (2 * value))
        payable
    {
        emit PurchaseConfirmed();
        buyer = msg.sender;
        state = State.Locked;
        // PW: If the seller doesn't ship the good after this point, both sides lose 2*value money.
        //     If the buy receives the good but doesn't call confirmReceived(), seller loses 3*value money and buy loses value money.
    }

    /// Confirm that you (the buyer) received the item.
    /// This will release the locked ether.
    function confirmReceived()
        public
        onlyBuyer
        inState(State.Locked)
    {
        emit ItemReceived();
        // It is important to change the state first because
        // otherwise, the contracts called using `send` below
        // can call in again here.
        state = State.Inactive;

        // NOTE: This actually allows both the buyer and the seller to
        // block the refund - the withdraw pattern should be used.

        /* buyer.transfer(value); */
        /* seller.transfer(address(this).balance); */
        
        buyerCanWithdraw = value;
        sellerCanWithdraw = address(this).balance;
    }

    function buyerWithdraw()
        public
        onlyBuyer
        inState(State.Inactive)
    {
      let value = buyerCanWithdraw;
      buyerCanWithdraw = 0;
      buyer.transfer(value);
    }
    
    function sellerWithdraw()
        public
        onlySeller
        inState(State.Inactive)
    {
      let value = sellerCanWithdraw;
      sellerCanWithdraw = 0;
      seller.transfer(value);
    }
    
}
