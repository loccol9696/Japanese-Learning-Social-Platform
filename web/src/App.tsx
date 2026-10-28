import React, { useState, useEffect } from 'react';
import { LoginForm } from './components/LoginForm';
import { DashboardView } from './components/DashboardView';
import { AdminDashboard } from './components/AdminDashboard';
import type { UserProfile } from './types/auth';
import { SESSION_EXPIRED_EVENT, clearSession, getToken, isTokenExpired, saveSession } from './services/session';

export const App: React.FC = () => {
  const [currentUser, setCurrentUser] = useState<UserProfile | null>(null);

  // Khôi phục phiên đã lưu, trừ khi token đã hết hạn.
  useEffect(() => {
    const savedUser = localStorage.getItem('jlsp_user');
    const token = getToken();
    if (savedUser && token) {
      if (isTokenExpired(token)) {
        clearSession();
        return;
      }
      try {
        setCurrentUser(JSON.parse(savedUser));
      } catch {
        clearSession();
      }
    }
  }, []);

  // Server từ chối token giữa chừng (hết hạn / bị thu hồi): về màn đăng nhập.
  useEffect(() => {
    const onExpired = () => setCurrentUser(null);
    window.addEventListener(SESSION_EXPIRED_EVENT, onExpired);
    return () => window.removeEventListener(SESSION_EXPIRED_EVENT, onExpired);
  }, []);

  const handleLoginSuccess = (user: UserProfile, token: string) => {
    setCurrentUser(user);
    saveSession(user, token);
  };

  const handleLogout = () => {
    setCurrentUser(null);
    clearSession();
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
