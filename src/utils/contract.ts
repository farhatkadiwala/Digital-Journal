import { ethers } from 'ethers';

// Replace with your deployed contract address
const CONTRACT_ADDRESS = "YOUR_DEPLOYED_CONTRACT_ADDRESS";

// ABI - Include only the functions we need for this basic frontend
const CONTRACT_ABI = [
    "function tutors(address) view returns (string memory name, uint256 ratePerHour, bool isListed, uint256 totalSessions, uint256 totalRating, bool isVerified)",
    "function bookSession(address tutor, uint256 duration) payable",
    "event TutorListed(address indexed tutor, string name, uint256 ratePerHour)",
    "function completeSession(uint256 sessionId, uint256 rating) external",
    "function sessions(uint256 sessionId) external view returns (uint256 rating, uint256 duration, uint256 timestamp)",
    "function getUserSessions(address user) external view returns (uint256[] memory)"
];

export const getContract = () => {
    if (!window.ethereum) {
        throw new Error("Please install MetaMask!");
    }

    const provider = new ethers.providers.Web3Provider(window.ethereum);
    const signer = provider.getSigner();
    return new ethers.Contract(CONTRACT_ADDRESS, CONTRACT_ABI, signer);
};

export const connectWallet = async () => {
    if (!window.ethereum) {
        throw new Error("Please install MetaMask!");
    }
    await window.ethereum.request({ method: 'eth_requestAccounts' });
};

// Add contract interaction functions
export const contractFunctions = {
  // Book a session with a tutor
  bookSession: async (tutorAddress: string, duration: number, amount: string) => {
    const contract = getContract();
    const tx = await contract.bookSession(tutorAddress, duration, {
      value: ethers.utils.parseEther(amount)
    });
    return await tx.wait();
  },

  // List yourself as a tutor
  listAsTutor: async (name: string, ratePerHour: string) => {
    const contract = getContract();
    const tx = await contract.listTutor(name, ethers.utils.parseEther(ratePerHour));
    return await tx.wait();
  },

  // Get tutor details
  getTutorDetails: async (address: string) => {
    const contract = getContract();
    return await contract.tutors(address);
  },

  // Complete a session
  completeSession: async (sessionId: number, rating: number) => {
    const contract = getContract();
    const tx = await contract.completeSession(sessionId, rating);
    return await tx.wait();
  },

  // Get session details
  getSession: async (sessionId: number) => {
    const contract = getContract();
    return await contract.sessions(sessionId);
  },

  // Get user's sessions
  getUserSessions: async (address: string) => {
    const contract = getContract();
    return await contract.getUserSessions(address);
  }
}; 