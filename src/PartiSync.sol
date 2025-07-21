// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./Particle.sol";

// This contract is used to payout the pulled funds from the users to the specified recipient.
// The payout is done in the form of a token transfer.
// The pull and payouts are done in a fixed interval of time which is set while deploying the contract.
contract PartiSync is Ownable, ReentrancyGuard {

    Particle public immutable particleToken;
    
    struct Subscription {
        address subscriber;      // User who is paying
        address recipient;       // Address receiving the payments
        uint256 amount;          // Amount per interval
        uint256 interval;        // Time interval in seconds
        uint256 lastPayout;      // Timestamp of last payout
        bool isActive;           // Whether subscription is active
        uint256 totalPaid;       // Total amount paid so far
    }
    
    mapping(uint256 => Subscription) public subscriptions;
    mapping(address => uint256[]) public userSubscriptions;
    mapping(address => uint256[]) public recipientSubscriptions;
    
    uint256 public nextSubscriptionId;
    uint256 public totalSubscriptions;
    
    event SubscriptionCreated(
        uint256 indexed subscriptionId,
        address indexed subscriber,
        address indexed recipient,
        uint256 amount,
        uint256 interval
    );
    
    event PayoutExecuted(
        uint256 indexed subscriptionId,
        address indexed subscriber,
        address indexed recipient,
        uint256 amount,
        uint256 timestamp
    );
    
    event SubscriptionCancelled(uint256 indexed subscriptionId);
    event SubscriptionPaused(uint256 indexed subscriptionId);
    event SubscriptionResumed(uint256 indexed subscriptionId);

    constructor(address _particleToken, address initialOwner) Ownable(initialOwner) {
        particleToken = Particle(_particleToken);
    }

    /**
     * @dev Create a new subscription
     * @param recipient Address to receive the payments
     * @param amount Amount of tokens per interval
     * @param interval Time interval in seconds between payments
     */
    function createSubscription(
        address recipient,
        uint256 amount,
        uint256 interval
    ) external nonReentrant returns (uint256) {
        require(recipient != address(0), "Invalid recipient");
        require(amount > 0, "Amount must be greater than 0");
        require(interval > 0, "Interval must be greater than 0");
        require(recipient != msg.sender, "Cannot subscribe to yourself");
        
        // Check if user has approved enough tokens
        uint256 allowance = particleToken.allowance(msg.sender, address(this));
        require(allowance >= amount, "Insufficient allowance");
        
        uint256 subscriptionId = nextSubscriptionId++;
        
        subscriptions[subscriptionId] = Subscription({
            subscriber: msg.sender,
            recipient: recipient,
            amount: amount,
            interval: interval,
            lastPayout: block.timestamp,
            isActive: true,
            totalPaid: 0
        });
        
        userSubscriptions[msg.sender].push(subscriptionId);
        recipientSubscriptions[recipient].push(subscriptionId);
        totalSubscriptions++;
        
        emit SubscriptionCreated(subscriptionId, msg.sender, recipient, amount, interval);
        
        return subscriptionId;
    }

    /**
     * @dev Execute payout for a specific subscription
     * @param subscriptionId ID of the subscription to payout
     */
    function executePayout(uint256 subscriptionId) external nonReentrant {
        Subscription storage subscription = subscriptions[subscriptionId];
        require(subscription.isActive, "Subscription is not active");
        require(block.timestamp >= subscription.lastPayout + subscription.interval, "Too early for payout");
        
        // Check if user has approved enough tokens
        uint256 allowance = particleToken.allowance(subscription.subscriber, address(this));
        require(allowance >= subscription.amount, "Insufficient allowance");
        
        // Transfer tokens from subscriber to recipient
        require(
            particleToken.transferFrom(subscription.subscriber, subscription.recipient, subscription.amount),
            "Transfer failed"
        );
        
        subscription.lastPayout = block.timestamp;
        subscription.totalPaid += subscription.amount;
        
        emit PayoutExecuted(
            subscriptionId,
            subscription.subscriber,
            subscription.recipient,
            subscription.amount,
            block.timestamp
        );
    }

    function claimPayout(uint256 subscriptionId) external nonReentrant {
        Subscription storage subscription = subscriptions[subscriptionId];
        require(subscription.isActive, "Subscription is not active");
        require(block.timestamp >= subscription.lastPayout + subscription.interval, "Too early for payout");
        require(subscription.recipient == msg.sender, "Only recipient can claim payout");
        // Transfer tokens from subscriber to recipient
        require(
            particleToken.transferFrom(subscription.subscriber, subscription.recipient, subscription.amount),
            "Transfer failed"
        );

        emit PayoutExecuted(subscriptionId, subscription.subscriber, subscription.recipient, subscription.amount, block.timestamp);
    }

    /**
     * @dev Execute payouts for all due subscriptions
     */
    function executeAllPayouts() external nonReentrant {
        uint256 executedCount = 0;
        
        for (uint256 i = 0; i < nextSubscriptionId; i++) {
            Subscription storage subscription = subscriptions[i];
            
            if (subscription.isActive && 
                block.timestamp >= subscription.lastPayout + subscription.interval) {
                
                uint256 allowance = particleToken.allowance(subscription.subscriber, address(this));
                
                if (allowance >= subscription.amount) {
                    // Transfer tokens from subscriber to recipient
                    if (particleToken.transferFrom(subscription.subscriber, subscription.recipient, subscription.amount)) {
                        subscription.lastPayout = block.timestamp;
                        subscription.totalPaid += subscription.amount;
                        
                        emit PayoutExecuted(
                            i,
                            subscription.subscriber,
                            subscription.recipient,
                            subscription.amount,
                            block.timestamp
                        );
                        
                        executedCount++;
                    }
                }
            }
        }
    }

    /**
     * @dev Cancel a subscription (only subscriber can cancel)
     * @param subscriptionId ID of the subscription to cancel
     */
    function cancelSubscription(uint256 subscriptionId) external {
        Subscription storage subscription = subscriptions[subscriptionId];
        require(subscription.subscriber == msg.sender, "Only subscriber can cancel");
        require(subscription.isActive, "Subscription is not active");
        
        subscription.isActive = false;
        
        emit SubscriptionCancelled(subscriptionId);
    }

    /**
     * @dev Pause a subscription (only owner can pause)
     * @param subscriptionId ID of the subscription to pause
     */
    function pauseSubscription(uint256 subscriptionId) external onlyOwner {
        Subscription storage subscription = subscriptions[subscriptionId];
        require(subscription.isActive, "Subscription is not active");
        
        subscription.isActive = false;
        
        emit SubscriptionPaused(subscriptionId);
    }

    /**
     * @dev Resume a subscription (only owner can resume)
     * @param subscriptionId ID of the subscription to resume
     */
    function resumeSubscription(uint256 subscriptionId) external onlyOwner {
        Subscription storage subscription = subscriptions[subscriptionId];
        require(!subscription.isActive, "Subscription is already active");
        
        subscription.isActive = true;
        
        emit SubscriptionResumed(subscriptionId);
    }

    /**
     * @dev Get all subscriptions for a user
     * @param user Address of the user
     * @return Array of subscription IDs
     */
    function getUserSubscriptions(address user) external view returns (uint256[] memory) {
        return userSubscriptions[user];
    }

    /**
     * @dev Get all subscriptions for a recipient
     * @param recipient Address of the recipient
     * @return Array of subscription IDs
     */
    function getRecipientSubscriptions(address recipient) external view returns (uint256[] memory) {
        return recipientSubscriptions[recipient];
    }

    /**
     * @dev Get subscription details
     * @param subscriptionId ID of the subscription
     * @return Subscription details
     */
    function getSubscription(uint256 subscriptionId) external view returns (Subscription memory) {
        return subscriptions[subscriptionId];
    }

    /**
     * @dev Check if a subscription is due for payout
     * @param subscriptionId ID of the subscription
     * @return True if payout is due
     */
    function isPayoutDue(uint256 subscriptionId) external view returns (bool) {
        Subscription storage subscription = subscriptions[subscriptionId];
        return subscription.isActive && 
               block.timestamp >= subscription.lastPayout + subscription.interval;
    }

    /**
     * @dev Get the next payout time for a subscription
     * @param subscriptionId ID of the subscription
     * @return Timestamp of next payout
     */
    function getNextPayoutTime(uint256 subscriptionId) external view returns (uint256) {
        Subscription storage subscription = subscriptions[subscriptionId];
        return subscription.lastPayout + subscription.interval;
    }
}