// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract EDUchain is ReentrancyGuard, Ownable {
    // Constants
    uint8 private constant MIN_RATING = 1;
    uint8 private constant MAX_RATING = 5;
    uint256 private constant MINIMUM_SESSION_DURATION = 30 minutes;
    uint256 private constant SESSION_TIMEOUT = 24 hours;
    uint256 private constant BASE_TUTOR_SHARE_PERCENTAGE = 80; // 80% base payment

    struct Tutor {
        string name;
        uint256 ratePerHour;
        bool isListed;
        uint256 totalSessions;
        uint256 totalRating;
        bool isVerified;
    }

    struct Session {
        address user;
        address tutor;
        uint256 amount;
        uint256 duration;
        uint256 startTime;
        uint256 bookedAt;
        SessionStatus status;
        uint8 rating;
    }

    enum SessionStatus {
        Booked,     // 0: Initial state when session is booked
        InProgress, // 1: Session has started
        Completed,  // 2: Session completed and rated
        Cancelled,  // 3: Session cancelled before start
        Disputed,   // 4: Session under dispute
        TimedOut    // 5: Session timed out
    }

    // State variables
    mapping(address => Tutor) public tutors;
    mapping(uint256 => Session) public sessions;
    mapping(address => uint256[]) public tutorSessions;
    mapping(address => uint256[]) public userSessions;
    
    uint256 public sessionCount;
    uint256 public platformFee = 5; // 5% platform fee
    
    // Events
    event TutorListed(address indexed tutor, string name, uint256 ratePerHour);
    event TutorUpdated(address indexed tutor, uint256 newRate);
    event TutorVerified(address indexed tutor);
    event SessionBooked(uint256 indexed sessionId, address indexed user, address indexed tutor, uint256 amount, uint256 duration);
    event SessionStarted(uint256 indexed sessionId, uint256 startTime);
    event SessionCompleted(uint256 indexed sessionId, uint8 rating);
    event SessionCancelled(uint256 indexed sessionId, string reason);
    event SessionDisputed(uint256 indexed sessionId);
    event PaymentProcessed(uint256 indexed sessionId, uint256 tutorShare, uint256 userRefund);
    
    // Constructor
    constructor() Ownable(msg.sender) {
        // Initialize contract with deployer as owner
    }

    // Modifiers
    modifier onlyTutor(uint256 _sessionId) {
        require(sessions[_sessionId].tutor == msg.sender, "Only tutor can perform this action");
        _;
    }

    modifier onlyStudent(uint256 _sessionId) {
        require(sessions[_sessionId].user == msg.sender, "Only student can perform this action");
        _;
    }

    modifier validSession(uint256 _sessionId) {
        require(_sessionId < sessionCount, "Invalid session ID");
        _;
    }

    // Tutor Management Functions
    function listTutor(string memory _name, uint256 _ratePerHour) external {
        require(_ratePerHour > 0, "Rate must be greater than zero");
        require(!tutors[msg.sender].isListed, "Tutor already listed");
        
        tutors[msg.sender] = Tutor({
            name: _name,
            ratePerHour: _ratePerHour,
            isListed: true,
            totalSessions: 0,
            totalRating: 0,
            isVerified: false
        });
        
        emit TutorListed(msg.sender, _name, _ratePerHour);
    }

    function updateTutorRate(uint256 _newRate) external {
        require(tutors[msg.sender].isListed, "Tutor not listed");
        require(_newRate > 0, "Rate must be greater than zero");
        tutors[msg.sender].ratePerHour = _newRate;
        emit TutorUpdated(msg.sender, _newRate);
    }

    // Admin Functions
    function verifyTutor(address _tutor) external onlyOwner {
        require(tutors[_tutor].isListed, "Tutor not listed");
        tutors[_tutor].isVerified = true;
        emit TutorVerified(_tutor);
    }

    function setPlatformFee(uint256 _newFee) external onlyOwner {
        require(_newFee <= 10, "Fee cannot exceed 10%");
        platformFee = _newFee;
    }

    // Session Management Functions
    function bookSession(address _tutor, uint256 _duration) external payable nonReentrant {
        require(tutors[_tutor].isListed, "Tutor not listed");
        require(_duration >= MINIMUM_SESSION_DURATION, "Session too short");
        
        uint256 expectedAmount = (tutors[_tutor].ratePerHour * _duration) / 1 hours;
        require(msg.value == expectedAmount, "Incorrect payment amount");

        uint256 sessionId = sessionCount++;
        sessions[sessionId] = Session({
            user: msg.sender,
            tutor: _tutor,
            amount: msg.value,
            duration: _duration,
            startTime: 0,
            bookedAt: block.timestamp,
            status: SessionStatus.Booked,
            rating: 0
        });

        tutorSessions[_tutor].push(sessionId);
        userSessions[msg.sender].push(sessionId);
        
        emit SessionBooked(sessionId, msg.sender, _tutor, msg.value, _duration);
    }

    function startSession(uint256 _sessionId) external 
        validSession(_sessionId) 
        onlyTutor(_sessionId) 
    {
        Session storage session = sessions[_sessionId];
        require(session.status == SessionStatus.Booked, "Session not in booked state");
        
        session.status = SessionStatus.InProgress;
        session.startTime = block.timestamp;
        
        emit SessionStarted(_sessionId, block.timestamp);
    }

    function completeSession(uint256 _sessionId, uint8 _rating) external 
        validSession(_sessionId) 
        onlyStudent(_sessionId) 
        nonReentrant 
    {
        Session storage session = sessions[_sessionId];
        require(session.status == SessionStatus.InProgress, "Session not in progress");
        require(_rating >= MIN_RATING && _rating <= MAX_RATING, "Invalid rating");

        session.status = SessionStatus.Completed;
        session.rating = _rating;
        
        // Update tutor stats
        Tutor storage tutor = tutors[session.tutor];
        tutor.totalSessions++;
        tutor.totalRating += _rating;

        _processPayment(_sessionId);
        
        emit SessionCompleted(_sessionId, _rating);
    }

    function cancelSession(uint256 _sessionId, string memory reason) external 
        validSession(_sessionId) 
        nonReentrant 
    {
        Session storage session = sessions[_sessionId];
        require(msg.sender == session.user || msg.sender == session.tutor, "Unauthorized");
        require(session.status == SessionStatus.Booked, "Can only cancel booked sessions");

        session.status = SessionStatus.Cancelled;
        
        // Refund the user
        (bool success, ) = payable(session.user).call{value: session.amount}("");
        require(success, "Refund failed");
        
        emit SessionCancelled(_sessionId, reason);
    }

    function raiseDispute(uint256 _sessionId) external 
        validSession(_sessionId) 
    {
        Session storage session = sessions[_sessionId];
        require(msg.sender == session.user || msg.sender == session.tutor, "Unauthorized");
        require(session.status == SessionStatus.InProgress, "Can only dispute active sessions");
        
        session.status = SessionStatus.Disputed;
        emit SessionDisputed(_sessionId);
    }

    // Internal Functions
    function _processPayment(uint256 _sessionId) internal {
        Session storage session = sessions[_sessionId];
        
        // Calculate shares
        uint256 platformShare = (session.amount * platformFee) / 100;
        uint256 baseAmount = session.amount - platformShare;
        
        // Calculate tutor's share based on rating (80% base + up to 20% based on rating)
        uint256 tutorShare = (baseAmount * BASE_TUTOR_SHARE_PERCENTAGE) / 100;
        uint256 ratingBonus = (baseAmount * (20 * (session.rating - 1))) / (100 * (MAX_RATING - 1));
        tutorShare += ratingBonus;
        
        uint256 userRefund = session.amount - tutorShare - platformShare;

        // Process payments
        (bool tutorSuccess, ) = payable(session.tutor).call{value: tutorShare}("");
        require(tutorSuccess, "Tutor payment failed");

        if (userRefund > 0) {
            (bool userSuccess, ) = payable(session.user).call{value: userRefund}("");
            require(userSuccess, "User refund failed");
        }

        emit PaymentProcessed(_sessionId, tutorShare, userRefund);
    }

    // View Functions
    function getTutorRating(address _tutor) external view returns (uint256) {
        Tutor storage tutor = tutors[_tutor];
        if (tutor.totalSessions == 0) return 0;
        return tutor.totalRating / tutor.totalSessions;
    }

    function getTutorSessions(address _tutor) external view returns (uint256[] memory) {
        return tutorSessions[_tutor];
    }

    function getUserSessions(address _user) external view returns (uint256[] memory) {
        return userSessions[_user];
    }

    // Function to withdraw platform fees (only owner)
    function withdrawPlatformFees() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No fees to withdraw");
        
        (bool success, ) = payable(owner()).call{value: balance}("");
        require(success, "Withdrawal failed");
    }
} 