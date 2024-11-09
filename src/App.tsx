import React from 'react';
import { BrowserRouter as Router, Routes, Route, Link, useLocation } from 'react-router-dom';
import { Cat } from 'lucide-react';
import { MainContent } from './components/MainContent';
import { ProfilePage } from './pages/ProfilePage';
import { ConnectButton } from './components/ConnectButton';
import { WalletProvider } from './context/WalletContext';

function Header() {
  const location = useLocation();
  
  return (
    <header className="bg-white border-b border-gray-200">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex items-center justify-between h-16">
          <nav className="flex space-x-8">
            <Link 
              to="/" 
              className={location.pathname === '/' ? 'text-primary font-medium' : 'text-secondary hover:text-primary'}
            >
              Tutors
            </Link>
            <Link 
              to="/profile" 
              className={location.pathname === '/profile' ? 'text-primary font-medium' : 'text-secondary hover:text-primary'}
            >
              Your profile
            </Link>
          </nav>
          <div className="flex items-center gap-4">
            <ConnectButton />
            <Cat className="w-6 h-6 text-primary" />
          </div>
        </div>
      </div>
    </header>
  );
}

function App() {
  return (
    <WalletProvider>
      <Router>
        <div className="min-h-screen bg-gray-100 font-sans">
          <Header />
          <Routes>
            <Route path="/" element={<MainContent />} />
            <Route path="/profile" element={<ProfilePage />} />
          </Routes>
        </div>
      </Router>
    </WalletProvider>
  );
}

export default App;