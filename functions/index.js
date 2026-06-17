const {onDocumentUpdated} = require("firebase-functions/v2/firestore");
const {onCall} = require("firebase-functions/v2/https");
const functions = require("firebase-functions");
const {initializeApp} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");
const {getMessaging} = require("firebase-admin/messaging");
const {getAuth} = require("firebase-admin/auth");

initializeApp();

// Kitchen → Dasher notification trigger
exports.notifyDasherOrderReady = onDocumentUpdated(
  "orders/{orderId}",
  async (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();

    if (before.status !== "readyForPickup" && after.status === "readyForPickup") {
      try {
        // 1. Log status change event
        await getFirestore()
          .collection("order_status_events")
          .add({
            orderId: event.params.orderId,
            oldStatus: before.status,
            newStatus: "readyForPickup",
            kitchenId: after.kitchenId || "default_kitchen",
            kitchenName: after.kitchenName || "Delhi Nights",
            timestamp: new Date(),
            triggeredNotification: true,
          });

        // 2. Send push notification to assigned Dasher
        const payload = {
          notification: {
            title: "Order Ready! 🎯",
            body: `Order #${event.params.orderId.slice(-4)} ready for pickup from ${after.kitchenName || "Delhi Nights"}`,
          },
          data: {
            orderId: event.params.orderId,
            customerName: after.customerName || "",
            customerAddress: after.customerAddress || "",
            customerPhone: after.customerPhone || "",
            pickupLocation: after.kitchenLocation || "-37.71112804668473,144.5917238006204", // Delhi Nights
            estimatedFoodReadyTime: after.estimatedReadyTime || "",
            orderTotal: String(after.totalAmount || 0),
          },
        };

        // Send to assigned Dasher's topic
        await getMessaging().send({
          ...payload,
          topic: `dasher_${after.dasherId || "unassigned"}`,
        });

        console.log(`Sent pickup alert to dasher_${after.dasherId} for order ${event.params.orderId}`);
      } catch (error) {
        console.error("Cloud function error:", error);
      }
    }
  }
);

// Additional helper function for manual trigger if needed
exports.manualDasherNotify = onCall({
  region: "australia-southeast1" 
}, async (request) => {
  const {orderId} = request.data;
  const order = await getFirestore().collection("orders").doc(orderId).get();
  
  if (!order.exists || order.data().status !== "readyForPickup") {
    throw new functions.https.HttpsError("invalid-argument", "Invalid order status");
  }

  await getMessaging().send({
    notification: {
      title: "Manual Ready Notice",
      body: "Kitchen requested immediate pickup",
    },
    topic: `dasher_${order.data().dasherId || "all"}`,
  });
  
  return {success: true};
});

// Generate custom token for staff authentication
exports.generateStaffToken = onCall({
  region: "australia-southeast1"
}, async (request) => {
  try {
    const {staffId, phoneNumber, pin} = request.data;
    
    if (!staffId || !phoneNumber || !pin) {
      throw new functions.https.HttpsError(
        "invalid-argument", 
        "Missing required fields: staffId, phoneNumber, pin"
      );
    }

    // Verify staff exists and PIN is correct
    const staffDoc = await getFirestore()
      .collection("staff")
      .doc(staffId)
      .get();

    if (!staffDoc.exists) {
      throw new functions.https.HttpsError(
        "not-found", 
        "Staff account not found"
      );
    }

    const staffData = staffDoc.data();
    
    // Verify PIN using direct comparison
    if (staffData.pin !== pin) {
      throw new functions.https.HttpsError(
        "permission-denied", 
        "Invalid PIN"
      );
    }

    // Verify staff is active
    if (!staffData.isActive) {
      throw new functions.https.HttpsError(
        "permission-denied", 
        "Staff account is not active"
      );
    }

    // Determine user role and permissions based on staff data
    const userRole = staffData.role || "staff";
    let permissions = [];
    
    if (userRole === "admin") {
      permissions = [
        "manage_staff",
        "view_all_attendance",
        "manage_schedules",
        "view_reports",
        "manage_system",
        "check_in_out",
        "view_own_attendance",
        "view_own_schedule",
        "update_own_profile"
      ];
    } else {
      permissions = [
        "check_in_out",
        "view_own_attendance",
        "view_own_schedule",
        "update_own_profile"
      ];
    }

    // Create custom claims for the user
    const customClaims = {
      role: userRole,
      staffId: staffId,
      department: staffData.department || "general",
      position: staffData.role || "staff",
      phoneNumber: phoneNumber,
      permissions: permissions,
      isAdmin: userRole === "admin"
    };

    // Generate custom token with claims
    const customToken = await getAuth().createCustomToken(staffId, customClaims);

    // Log the authentication event
    await getFirestore()
      .collection("staff_auth_logs")
      .add({
        staffId: staffId,
        phoneNumber: phoneNumber,
        role: userRole,
        timestamp: new Date(),
        action: "custom_token_generated",
        success: true
      });

    return {
      success: true,
      customToken: customToken,
      staffData: {
        id: staffId,
        name: staffData.name,
        department: staffData.department,
        role: userRole,
        phoneNumber: phoneNumber,
        isAdmin: userRole === "admin"
      }
    };

  } catch (error) {
    console.error("Error generating staff token:", error);
    
    // Log failed authentication attempt
    if (request.data.staffId) {
      await getFirestore()
        .collection("staff_auth_logs")
        .add({
          staffId: request.data.staffId,
          phoneNumber: request.data.phoneNumber,
          timestamp: new Date(),
          action: "custom_token_generation_failed",
          success: false,
          error: error.message
        });
    }

    throw error;
  }
});