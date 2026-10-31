import React, { useState, useEffect } from 'react';
import { LoginForm } from './components/LoginForm';
import { DashboardView } from './components/DashboardView';
import { AdminDashboard } from './components/AdminDashboard';
import type { UserProfile } from './types/auth';

export const App: React.FC = () => {
  const [currentUser, setCurrentUser] = useState<UserProfile | null>(null);

  // Restore session from localStorage if available (Bỏ qua và xóa sạch token demo cũ)
  useEffect(() => {
    const savedUser = localStorage.getItem('jlsp_user');
    const token = localStorage.getItem('jlsp_token');
    if (savedUser && token) {
      if (token.startsWith('demo_') || token.startsWith('mock_')) {
        localStorage.removeItem('jlsp_user');
        localStorage.removeItem('jlsp_token');
        return;
      }
      try {
        setCurrentUser(JSON.parse(savedUser));
      } catch (e) {
        localStorage.removeItem('jlsp_user');
        localStorage.removeItem('jlsp_token');
      }
    }
  }, []);

  const handleLoginSuccess = (user: UserProfile, token: string) => {
    setCurrentUser(user);
    localStorage.setItem('jlsp_user', JSON.stringify(user));
    localStorage.setItem('jlsp_token', token);
  };

  const handleLogout = () => {
    setCurrentUser(null);
    localStorage.removeItem('jlsp_user');
    localStorage.removeItem('jlsp_token');
  };

  return (
    <>
      {/* Dynamic Background Atmosphere (Only for Login view) */}
      {!currentUser && (
        <>
          <div className="ambient-bg" />
          <div className="noise-layer" />
        </>
      )}

      {/* Conditional Routing: Guest -> Login, Admin/Mod -> AdminDashboard, User -> DashboardView */}
      {!currentUser && (
        <LoginForm onLoginSuccess={handleLoginSuccess} />
      )}

      {currentUser && (currentUser.role === 'ADMIN' || currentUser.role === 'MODERATOR') ? (
        <AdminDashboard
          user={currentUser}
          onLogout={handleLogout}
          onUpdateUser={(updated) => {
            setCurrentUser(updated);
            localStorage.setItem('jlsp_user', JSON.stringify(updated));
          }}
        />
      ) : currentUser ? (
        <DashboardView user={currentUser} onLogout={handleLogout} />
      ) : null}
    </>
  );
};

export default App;
