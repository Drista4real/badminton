import React, { useState, useEffect } from 'react';
import Sidebar from './components/Sidebar';
import RoleHeader from './components/RoleHeader';
import DashboardView from './components/DashboardView';
import PosGridView from './components/PosGridView';
import CustomersView from './components/CustomersView';
import CourtsView from './components/CourtsView';
import FinanceView from './components/FinanceView';
import PricingView from './components/PricingView';
import LoginView from './components/LoginView';
import RefundsApprovalView from './components/RefundsApprovalView';

import { Court, Booking, Customer, RefundRequest, PricingRule } from './types';
import { 
  INITIAL_COURTS, 
  INITIAL_BOOKINGS, 
  INITIAL_CUSTOMERS, 
  INITIAL_REFUNDS, 
  INITIAL_PRICING_RULES 
} from './data';

import { parseVietnameseDateToISO, formatVietnameseDate } from './components/RoleHeader';

export const getLocalDateString = (d: Date | number = new Date()): string => {
  const dateObj = typeof d === 'number' ? new Date(d) : d;
  const year = dateObj.getFullYear();
  const month = String(dateObj.getMonth() + 1).padStart(2, '0');
  const day = String(dateObj.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
};

export default function App() {
  const [courts, setCourts] = useState<Court[]>(INITIAL_COURTS);
  const [bookings, setBookings] = useState<Booking[]>(INITIAL_BOOKINGS);
  const [customers, setCustomers] = useState<Customer[]>(INITIAL_CUSTOMERS);
  const [refunds, setRefunds] = useState<RefundRequest[]>(INITIAL_REFUNDS);
  const [pricingRules, setPricingRules] = useState<PricingRule[]>(INITIAL_PRICING_RULES);

  // Authentication & session management
  const [currentUser, setCurrentUser] = useState<{ id: string; name: string; email: string; phone: string; role: string } | null>(() => {
    const saved = localStorage.getItem('court_admin_user');
    return saved ? JSON.parse(saved) : null;
  });

  // Role management (restored on page refresh)
  const [currentRole, setRole] = useState<'staff' | 'accountant' | 'admin'>(() => {
    const saved = localStorage.getItem('court_admin_user');
    if (saved) {
      try {
        const u = JSON.parse(saved);
        if (u && u.role) return u.role as 'staff' | 'accountant' | 'admin';
      } catch (e) {
        console.error('Error parsing role on mount', e);
      }
    }
    return 'admin';
  });
  
  const [activeTab, setActiveTab] = useState<string>(() => {
    const saved = localStorage.getItem('court_admin_user');
    if (saved) {
      try {
        const u = JSON.parse(saved);
        if (u.role === 'staff') return 'pos';
      } catch (e) {}
    }
    return 'dashboard';
  });
  
  // Date context
  const [selectedDate, setSelectedDate] = useState<string>(getLocalDateString());
  const [searchQuery, setSearchQuery] = useState<string>('');

  // Fetch Firestore Data function (Component-level so it is re-callable)
  const fetchFirestoreData = async () => {
    try {
      let firestoreUsers: any[] = [];
      const usersRes = await fetch('/api/data-users');
      if (usersRes.ok) {
        firestoreUsers = await usersRes.json();
        if (firestoreUsers.length === 0) {
          for (const c of INITIAL_CUSTOMERS) {
            await fetch('/api/data-users', {
              method: 'POST',
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify(c)
            });
          }
          const retryRes = await fetch('/api/data-users');
          if (retryRes.ok) {
            firestoreUsers = await retryRes.json();
          }
        }
        const mappedUsers: Customer[] = firestoreUsers.map((u: any) => ({
          id: u.id,
          name: u.fullName || u.displayName || u.name || 'Unnamed',
          email: u.email || '',
          phone: u.phone || u.phoneNumber || '',
          role: u.role || 'customer',
          points: u.rankScore !== undefined ? u.rankScore : (u.points || 0),
          isLocked: u.isLocked === true || u.isLocked === 'true' || u.isDisabled === true || u.isDisabled === 'true',
          joinedDate: u.createdAt?._seconds ? getLocalDateString(u.createdAt._seconds * 1000) : getLocalDateString()
        }));
        setCustomers(mappedUsers);
      }

      const courtsRes = await fetch('/api/data-courts');
      if (courtsRes.ok) {
        let firestoreCourts = await courtsRes.json();
        if (firestoreCourts.length === 0) {
          for (const c of INITIAL_COURTS) {
            await fetch('/api/data-courts', {
              method: 'POST',
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify(c)
            });
          }
          const retryRes = await fetch('/api/data-courts');
          if (retryRes.ok) {
            firestoreCourts = await retryRes.json();
          }
        }
        // Sort courts by ID numerically to ensure a fully stable court ordering on page load/reload
        firestoreCourts.sort((a: any, b: any) => {
          return a.id.localeCompare(b.id, undefined, { numeric: true, sensitivity: 'base' });
        });
        const mappedCourts: Court[] = firestoreCourts.map((c: any) => ({
          ...c,
          id: c.id,
          name: c.name || `Sân ${c.id}`,
          type: c.type || 'Thảm PVC',
          pricePerHour: c.pricePerHour || 100000,
          isActive: c.isActive !== false,
          image: c.image || 'https://images.unsplash.com/photo-1626224583760-49e0c52bbef3?w=500&q=80'
        }));
        setCourts(mappedCourts);
      }

      const bookingsRes = await fetch('/api/data-bookings');
      if (bookingsRes.ok) {
        let firestoreBookings = await bookingsRes.json();
        if (firestoreBookings.length === 0) {
          for (const b of INITIAL_BOOKINGS) {
            await fetch('/api/data-bookings', {
              method: 'POST',
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify(b)
            });
          }
          const retryRes = await fetch('/api/data-bookings');
          if (retryRes.ok) {
            firestoreBookings = await retryRes.json();
          }
        }
        const mappedBookings: Booking[] = firestoreBookings.map((b: any) => {
          let dateStr = getLocalDateString();
          if (b.date) {
            if (b.date._seconds !== undefined) {
              dateStr = getLocalDateString(b.date._seconds * 1000);
            } else if (b.date.seconds !== undefined) {
              dateStr = getLocalDateString(b.date.seconds * 1000);
            } else if (typeof b.date === 'string' || typeof b.date === 'number' || b.date instanceof Date) {
              dateStr = getLocalDateString(new Date(b.date));
            }
          }
          
          const startH = Math.floor(b.startTime / 60).toString().padStart(2, '0');
          const startM = (b.startTime % 60).toString().padStart(2, '0');
          const endH = Math.floor(b.endTime / 60).toString().padStart(2, '0');
          const endM = (b.endTime % 60).toString().padStart(2, '0');
          
          const statusMap: Record<string, any> = {
            'pending': 'Pending',
            'confirmed': 'Confirmed',
            'completed': 'Completed',
            'cancelled': 'Cancelled',
            'no-show': 'No-show',
            'no_show': 'No-show'
          };

          const matchedUser = firestoreUsers.find(u => u.id === b.userId);
          let customerName = b.userId || 'User';
          if (matchedUser) {
             customerName = matchedUser.fullName || matchedUser.displayName || matchedUser.name || customerName;
          } else if (b.walkinName) {
             customerName = b.walkinName;
          } else if (b.customerName) {
             customerName = b.customerName; // For the simple mock override
          }
          
          return {
            id: b.id,
            courtId: b.courtId || 'unknown',
            date: dateStr,
            startTime: `${startH}:${startM}`,
            endTime: `${endH}:${endM}`,
            status: statusMap[b.status] || 'Pending',
            customerType: matchedUser ? 'App' : 'Walkin',
            customerName: customerName,
            totalAmount: b.totalPrice || 0,
            createdAt: getLocalDateString()
          };
        });
        setBookings(mappedBookings);
      }

      const refundsRes = await fetch('/api/data-refunds');
      if (refundsRes.ok) {
        const firestoreRefunds = await refundsRes.json();
        const mappedRefunds: RefundRequest[] = firestoreRefunds.map((w: any) => ({
          id: w.id,
          bookingId: w.bookingId || w.orderId || 'N/A',
          customerName: w.customerName || 'User',
          bankName: w.bankName || 'Ví Nội Bộ',
          accountNumber: w.accountNumber || 'N/A',
          accountHolder: w.accountHolder || 'N/A',
          amount: w.amount || 0,
          status: w.status === 'Cancelled' ? 'Cancelled' : 'Refund_Pending',
          courtName: 'Chi tiết ngân sách',
          timeSlot: w.timeSlot || '-',
          date: w.date || getLocalDateString(),
          ...w
        }));
        setRefunds(mappedRefunds);
      }
      
      const priceRes = await fetch('/api/data-pricing');
      if (priceRes.ok) {
         let dbPricing = await priceRes.json();
         if (dbPricing.length < 8) {
           // Seed database with the initial rules if outdated or empty
           for (const r of INITIAL_PRICING_RULES) {
             await fetch(`/api/data-pricing/${r.id}`, {
               method: 'PUT',
               headers: { 'Content-Type': 'application/json' },
               body: JSON.stringify(r)
             });
           }
           const retryRes = await fetch('/api/data-pricing');
           if (retryRes.ok) {
             dbPricing = await retryRes.json();
           }
         }
         if (dbPricing.length > 0) {
           dbPricing.sort((a: any, b: any) => {
             // Ensure exact sequential order from pr1 to pr8
             return a.id.localeCompare(b.id, undefined, { numeric: true, sensitivity: 'base' });
           });
           setPricingRules(dbPricing);
         }
      }
    } catch (err) {
      console.error('Failed to fetch Firestore data', err);
    }
  };

  // Fetch Firestore Data on Mount and configure periodic automatic synchronization every 60 seconds to preserve daily quota
  useEffect(() => {
    fetchFirestoreData();
    
    const interval = setInterval(() => {
      fetchFirestoreData();
    }, 60000); // Poll Firestore every 60 seconds automatically (optimized to save quota)
    
    return () => clearInterval(interval);
  }, []);

  // Adjust active tab when switching roles to avoid hidden tabs
  const handleRoleChange = (role: 'staff' | 'accountant' | 'admin') => {
    setRole(role);
    if (role === 'staff') {
      setActiveTab('pos');
    } else if (role === 'accountant') {
      setActiveTab('dashboard');
    } else {
      setActiveTab('dashboard');
    }
  };

  // State handlers
  const handleAddBooking = async (newBooking: Booking) => {
    // Optimistic UI
    setBookings(prev => [newBooking, ...prev]);

    try {
      const res = await fetch('/api/data-bookings', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(newBooking)
      });
      if (!res.ok) {
        console.error('Failed to create booking in DB');
      }
    } catch (err) {
      console.error(err);
    }
  };

  const handleUpdateBookingStatus = async (id: string, newStatus: Booking['status'], updates?: any) => {
    setBookings(prev => prev.map(booking => {
      if (booking.id === id) {
        return { ...booking, status: newStatus, ...updates };
      }
      return booking;
    }));

    try {
      await fetch(`/api/data-bookings/${id}`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ status: newStatus, ...updates })
      });
    } catch(err) {
      console.error(err);
    }
  };

  const handleToggleLockCustomer = async (id: string) => {
    const targetCustomer = customers.find(c => c.id === id);
    if (!targetCustomer) return;

    // Prevent Admin from being locked at the frontend level
    if (targetCustomer.email === 'Admin@gmail.com' || targetCustomer.phone === '0987654321') {
      alert('Thao tác không hợp lệ. Không thể khóa tài khoản Admin hệ thống!');
      return;
    }

    const newLockStatus = !targetCustomer.isLocked;

    // 1. Optimistic Update
    setCustomers(prev => prev.map(cust => 
      cust.id === id ? { ...cust, isLocked: newLockStatus } : cust
    ));

    // 2. Persist to Firestore DB
    try {
      const response = await fetch(`/api/data-users/${id}/lock`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ isLocked: newLockStatus })
      });

      if (response.ok) {
        // Re-fetch users to confirm changes are correctly saved & loaded from Firestore
        const fetchRes = await fetch('/api/data-users');
        if (fetchRes.ok) {
          const firestoreUsers = await fetchRes.json();
          const mappedUsers: Customer[] = firestoreUsers.map((u: any) => ({
            id: u.id,
            name: u.fullName || u.displayName || u.name || 'Unnamed',
            email: u.email || '',
            phone: u.phone || u.phoneNumber || '',
            role: u.role || 'customer',
            points: u.rankScore !== undefined ? u.rankScore : (u.points || 0),
            isLocked: u.isLocked === true || u.isLocked === 'true' || u.isDisabled === true || u.isDisabled === 'true',
            joinedDate: u.createdAt?._seconds ? new Date(u.createdAt._seconds * 1000).toISOString().split('T')[0] : new Date().toISOString().split('T')[0]
          }));
          setCustomers(mappedUsers);
        }
      } else {
        console.error('Failed to update DB lock status');
        // Rollback state
        setCustomers(prev => prev.map(cust => 
          cust.id === id ? { ...cust, isLocked: !newLockStatus } : cust
        ));
      }
    } catch(err) {
      console.error('Lock error:', err);
      // Rollback state
      setCustomers(prev => prev.map(cust => 
        cust.id === id ? { ...cust, isLocked: !newLockStatus } : cust
      ));
    }
  };

  const handleAddCustomer = async (newCustomer: Customer) => {
    setCustomers(prev => [...prev, newCustomer]);
    try {
      await fetch('/api/data-users', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(newCustomer)
      });
    } catch (err) {
      console.error("Failed to add customer to database:", err);
    }
  };

  const handleToggleCourtActive = async (id: string) => {
    // Find client-side court before update to retrieve previous status and details
    const courtToUpdate = courts.find(c => c.id === id);
    if (!courtToUpdate) return;

    const newActiveStatus = !courtToUpdate.isActive;
    const targetCourt: Court = { 
      ...courtToUpdate, 
      isActive: newActiveStatus,
      isMaintenance: !newActiveStatus,
      status: newActiveStatus ? 'active' : 'maintenance'
    };

    if (newActiveStatus) {
      targetCourt.isProtected = false;
      targetCourt.protectedReason = "";
    }

    // Update React state optimistically
    setCourts(prev => prev.map(court => court.id === id ? targetCourt : court));

    // Persist status change to backend database synchronously
    try {
      const response = await fetch(`/api/data-courts/${id}`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(targetCourt)
      });
      if (!response.ok) {
        console.error("Failed to update court active status on server");
        // Rollback state if server update fails
        setCourts(prev => prev.map(court => court.id === id ? courtToUpdate : court));
      }
    } catch (err) {
      console.error("Failed to update court active status in database:", err);
      // Rollback state on network/unexpected error
      setCourts(prev => prev.map(court => court.id === id ? courtToUpdate : court));
    }
  };

  const handleAddCourt = async (newCourt: Court) => {
    const syncedCourt: Court = {
      ...newCourt,
      isMaintenance: !newCourt.isActive,
      status: newCourt.isActive ? 'active' : 'maintenance'
    };
    setCourts(prev => [...prev, syncedCourt]);
    try {
      await fetch('/api/data-courts', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(syncedCourt)
      });
    } catch (err) {
      console.error("Failed to add court to database:", err);
    }
  };

  const handleUpdateCourt = async (updatedCourt: Court) => {
    const syncedCourt: Court = {
      ...updatedCourt,
      isMaintenance: !updatedCourt.isActive,
      status: updatedCourt.isActive ? 'active' : 'maintenance'
    };

    if (syncedCourt.isActive) {
      syncedCourt.isProtected = false;
      syncedCourt.protectedReason = "";
    }

    setCourts(prev => prev.map(c => c.id === syncedCourt.id ? syncedCourt : c));
    try {
      await fetch(`/api/data-courts/${syncedCourt.id}`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(syncedCourt)
      });
    } catch (err) {
      console.error("Failed to update court in database:", err);
    }
  };

  const handleUpdatePricing = async (id: string, updatedFields: Partial<PricingRule>) => {
    setPricingRules(prev => prev.map(rule => rule.id === id ? { ...rule, ...updatedFields } : rule));
    try {
      await fetch(`/api/data-pricing/${id}`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(updatedFields)
      });
    } catch(err) {
      console.error(err);
    }
  };

  const handleAddPricingRule = async (newRule: PricingRule) => {
    setPricingRules(prev => [...prev, newRule].sort((a, b) => a.id.localeCompare(b.id, undefined, { numeric: true, sensitivity: 'base' })));
    try {
      await fetch(`/api/data-pricing/${newRule.id}`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(newRule)
      });
    } catch (err) {
      console.error(err);
    }
  };

  const handleResetPricing = async () => {
    try {
      for (const r of INITIAL_PRICING_RULES) {
        await fetch(`/api/data-pricing/${r.id}`, {
          method: 'PUT',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(r)
        });
      }
      const priceRes = await fetch('/api/data-pricing');
      if (priceRes.ok) {
         let dbPricing = await priceRes.json();
         dbPricing.sort((a: any, b: any) => a.id.localeCompare(b.id, undefined, { numeric: true, sensitivity: 'base' }));
         setPricingRules(dbPricing);
      }
    } catch(err) {
      console.error("Failed to reset pricing:", err);
    }
  };

  const handleApproveRefund = async (refundId: string) => {
    const refund = refunds.find(r => r.id === refundId);
    if (!refund) return;

    try {
      const refundRes = await fetch(`/api/data-refunds/${refundId}/complete`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
      });

      if (!refundRes.ok) {
        const errorData = await refundRes.json().catch(() => ({}));
        alert(errorData.error || 'Server error occurred during refund processing');
        return;
      }

      setRefunds(prev => prev.map(r => r.id === refundId ? { ...r, status: 'Cancelled' } : r));
      setBookings(prev => prev.map(b => b.id === refund.bookingId ? { ...b, status: 'Cancelled' } : b));

      // Display success message
      alert(`Xác nhận hoàn tiền thành công!\nYêu cầu ${refund.id} trị giá ${refund.amount.toLocaleString('vi-VN')}đ đã được chuyển khoản thủ công.`);

    } catch(err) {
      console.error(err);
      alert('Network error while processing refund');
    }
  };

  if (!currentUser) {
    return (
      <LoginView 
        onLoginSuccess={(user) => {
          setCurrentUser(user);
          localStorage.setItem('court_admin_user', JSON.stringify(user));
          setRole(user.role as any);
        }} 
      />
    );
  }

  return (
    <div className="flex h-screen bg-[#F8FAFC] overflow-hidden font-sans">
      {/* Dynamic Sidebar navigation */}
      <Sidebar 
        currentRole={currentRole} 
        activeTab={activeTab} 
        setActiveTab={setActiveTab} 
        onLogout={() => {
          setCurrentUser(null);
          localStorage.removeItem('court_admin_user');
        }}
      />

      {/* Main app block container */}
      <div className="flex-1 flex flex-col h-screen overflow-hidden">
        {/* Header navigation bar */}
        <RoleHeader
          currentRole={currentRole}
          setRole={handleRoleChange}
          selectedDate={selectedDate}
          setSelectedDate={setSelectedDate}
          searchQuery={searchQuery}
          setSearchQuery={setSearchQuery}
          activeTab={activeTab}
        />

        {/* Dynamic content screen wrapper */}
        <main className="flex-1 overflow-y-auto p-6">
          {activeTab === 'dashboard' && (
            <DashboardView 
              selectedDateISO={selectedDate}
              bookings={bookings} 
              courts={courts} 
              customers={customers} 
              refundsCount={refunds.filter(r => r.status === 'Refund_Pending').length}
            />
          )}

          {activeTab === 'pos' && (
            <PosGridView
              selectedDateISO={selectedDate}
              courts={courts}
              bookings={bookings}
              customers={customers}
              pricingRules={pricingRules}
              onAddBooking={handleAddBooking}
              onUpdateBookingStatus={handleUpdateBookingStatus}
            />
          )}

          {activeTab === 'customers' && (
            <CustomersView
              customers={customers}
              onToggleLockCustomer={handleToggleLockCustomer}
              onAddCustomer={handleAddCustomer}
            />
          )}

          {activeTab === 'courts' && (
            <CourtsView
              courts={courts}
              onToggleCourtActive={handleToggleCourtActive}
              onAddCourt={handleAddCourt}
              onUpdateCourt={handleUpdateCourt}
            />
          )}

          {activeTab === 'finance' && (
            <FinanceView
              refunds={refunds}
              bookings={bookings}
              onApproveRefund={handleApproveRefund}
            />
          )}

          {activeTab === 'refunds-review' && (
            <RefundsApprovalView
              refunds={refunds}
              bookings={bookings}
              onApproveRefund={handleApproveRefund}
            />
          )}

          {activeTab === 'pricing' && (
            <PricingView
              courts={courts}
              onUpdateCourt={handleUpdateCourt}
            />
          )}
        </main>
      </div>
    </div>
  );
}
