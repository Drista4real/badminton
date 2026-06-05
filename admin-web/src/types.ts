export interface Court {
  id: string;
  name: string;
  type: 'Thảm PVC' | 'Sàn Gỗ' | 'Bê tông';
  pricePerHour: number;
  isActive: boolean;
  image: string;
  isMaintenance?: boolean;
  status?: string;
  isProtected?: boolean;
  protectedReason?: string;
  protectedAt?: any;
  surfaceType?: string;
  description?: string;
  code?: string;
  peakPrice?: number;
  fixedSchedulePrice?: number;
  hourlyRate?: number;
  basePrice?: number;
  hourlyPrices?: any;
  createdAt?: any;
  updatedAt?: any;
  images?: any[];
  imageUrl?: string | null;
  [key: string]: any;
}

export interface Booking {
  id: string;
  courtId: string;
  date: string; // YYYY-MM-DD
  startTime: string; // e.g. "08:00"
  endTime: string; // e.g. "09:30"
  status: 'Pending' | 'Confirmed' | 'Completed' | 'Cancelled' | 'No-show';
  customerType: 'App' | 'Walkin';
  customerName: string;
  customerPhone?: string;
  customerEmail?: string;
  totalAmount: number;
  createdAt: string;
  pointsEarned?: number;
  customerId?: string;
}

export interface RefundRequest {
  id: string;
  bookingId: string;
  customerName: string;
  bankName: string;
  accountNumber: string;
  accountHolder: string;
  amount: number;
  status: 'Refund_Pending' | 'Cancelled';
  courtName: string;
  timeSlot: string;
  date: string;
}

export interface PricingRule {
  id: string;
  dayType: 'T2 - T6' | 'T7 - CN' | 'T2 - CN';
  timeSlot: string; // e.g. "5h - 9h"
  fixedCustPrice: number;
  appCustPrice: number;
  walkinPrice: number;
}

export interface Customer {
  id: string;
  name: string;
  email: string;
  phone: string;
  role?: string;
  points: number;
  isLocked: boolean;
  joinedDate: string;
}
