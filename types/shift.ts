// Shift type definition for Firestore-backed roster data
// This file provides TypeScript typing for shifts to aid web tooling,
// cloud functions, and any TypeScript consumers of the same database.

export interface Shift {
  id: string;
  staffId: string;
  staffName: string;
  role: string;
  department?: string;
  date: Date; // start-of-day for the scheduled date
  startTime: Date;
  endTime: Date;
  location?: string;
  notes?: string;
}

// Firestore data shape as stored (timestamps)
export interface ShiftDoc {
  staffId: string;
  staffName?: string;
  role?: string;
  department?: string;
  date: FirebaseFirestore.Timestamp;
  startTime: FirebaseFirestore.Timestamp;
  endTime: FirebaseFirestore.Timestamp;
  location?: string;
  notes?: string;
}

// Converter helpers (optional) for web/Node TS consumers
export const shiftConverter = {
  toFirestore(shift: Shift): ShiftDoc {
    return {
      staffId: shift.staffId,
      staffName: shift.staffName,
      role: shift.role,
      department: shift.department,
      date: FirebaseFirestore.Timestamp.fromDate(shift.date),
      startTime: FirebaseFirestore.Timestamp.fromDate(shift.startTime),
      endTime: FirebaseFirestore.Timestamp.fromDate(shift.endTime),
      location: shift.location,
      notes: shift.notes,
    };
  },
  fromFirestore(id: string, doc: ShiftDoc): Shift {
    return {
      id,
      staffId: doc.staffId,
      staffName: doc.staffName ?? '',
      role: doc.role ?? '',
      department: doc.department,
      date: doc.date.toDate(),
      startTime: doc.startTime.toDate(),
      endTime: doc.endTime.toDate(),
      location: doc.location,
      notes: doc.notes,
    };
  },
};

// Example Firestore query (Node/TS):
// import { getFirestore } from 'firebase-admin/firestore';
// const db = getFirestore();
// const snapshot = await db.collection('shifts')
//   .where('date', '>=', Timestamp.fromDate(start))
//   .where('date', '<=', Timestamp.fromDate(end))
//   .get();
// const shifts: Shift[] = snapshot.docs.map(d => shiftConverter.fromFirestore(d.id, d.data() as ShiftDoc));

