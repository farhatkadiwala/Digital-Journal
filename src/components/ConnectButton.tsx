import React, { useState } from 'react';
import { useWallet } from '../context/WalletContext';

export function ConnectButton() {
  const { isConnected, account, connectWallet, chainId, error } = useWallet();
  const [isConnecting, setIsConnecting] = useState(false);

  const handleConnect = async () => {
    try {
      setIsConnecting(true);
      await connectWallet();
    } catch (err) {
      console.error('Connection failed:', err);
    } finally {
      setIsConnecting(false);
    }
  };

  if (error) {
    return (
      <div className="flex items-center gap-2">
        <button
          onClick={handleConnect}
          className="bg-red-500 text-white px-4 py-2 rounded-smooth hover:bg-red-600 transition-colors"
        >
          {error}
        </button>
      </div>
    );
  }

  if (isConnected && account) {
    return (
      <div className="flex items-center gap-2">
        <span className="px-4 py-2 bg-gray-100 rounded-smooth text-sm">
          {account.slice(0, 6)}...{account.slice(-4)}
        </span>
        <span className="text-sm text-gray-500">
          {chainId === '1' ? 'Ethereum' : 
           chainId === '137' ? 'Polygon' : 
           chainId === '5' ? 'Goerli' :
           chainId ? `Chain ID: ${chainId}` : ''}
        </span>
      </div>
    );
  }

  return (
    <button
      onClick={handleConnect}
      disabled={isConnecting}
      className="bg-primary text-white px-4 py-2 rounded-smooth hover:bg-primary/90 transition-colors disabled:opacity-50"
    >
      {isConnecting ? 'Connecting...' : 'Connect Wallet'}
    </button>
  );
} 

export default ConnectButton;