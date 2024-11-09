import React, { useState } from 'react';
import { useWallet } from '../context/WalletContext';
import { contractFunctions } from '../utils/contract';

export function TutorRegistration() {
  const [name, setName] = useState('');
  const [rate, setRate] = useState('');

  const handleRegistration = async () => {
    await contractFunctions.listAsTutor(name, rate);
  };

  return (
    <form onSubmit={handleRegistration}>
      {/* Registration form */}
    </form>
  );
} 