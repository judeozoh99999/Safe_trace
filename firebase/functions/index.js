const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

const db = admin.firestore();

// Scheduled function running every day at midnight (00:00 Lagos Time)
exports.purgeOldLocations = functions.region('europe-west3').pubsub.schedule('0 0 * * *')
  .timeZone('Africa/Lagos')
  .onRun(async (context) => {
    const sevenDaysAgo = new Date();
    sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7);

    console.log(`Starting purge of location entries older than: ${sevenDaysAgo.toISOString()}`);

    try {
      const usersSnap = await db.collection('users').get();
      let totalDeleted = 0;

      for (const userDoc of usersSnap.docs) {
        const userId = userDoc.id;
        const locationsRef = db.collection('users').doc(userId).collection('locations');
        
        // Find documents where timestamp is older than 7 days
        const oldLocationsSnap = await locationsRef
          .where('timestamp', '<', admin.firestore.Timestamp.fromDate(sevenDaysAgo))
          .get();

        if (oldLocationsSnap.empty) {
          continue;
        }

        const batch = db.batch();
        oldLocationsSnap.docs.forEach((doc) => {
          batch.delete(doc.ref);
          totalDeleted++;
        });

        await batch.commit();
        console.log(`Purged ${oldLocationsSnap.size} location records for user: ${userId}`);
      }

      console.log(`Purge run complete. Total documents deleted: ${totalDeleted}`);
      return null;
    } catch (error) {
      console.error('Error executing scheduled location logs purge:', error);
      throw error;
    }
  });

// ─── 3-Day Pending Deletions System ──────────────────────────────────────────

// Triggers on document update in trusted_circle_requests when status changes to pending_deletion
exports.onPendingDeletionCreated = functions.firestore
  .document('trusted_circle_requests/{docId}')
  .onUpdate(async (change, context) => {
    const beforeData = change.before.data();
    const afterData = change.after.data();

    if (!afterData) return null;
    if (beforeData.status !== 'pending_deletion' && afterData.status === 'pending_deletion') {
      const docId = context.params.docId;
      const initiatorUid = afterData.deletion_initiated_by || afterData.requester_uid;
      const recipientUid = (afterData.requester_uid === initiatorUid) ? afterData.recipient_uid : afterData.requester_uid;

      if (!recipientUid) return null;

      let initiatorFirstName = 'A trusted contact';
      if (initiatorUid === afterData.requester_uid) {
        initiatorFirstName = afterData.requester_first_name || 'Someone';
      } else {
        initiatorFirstName = afterData.recipient_first_name || 'Someone';
      }

      const title = 'Trusted Circle Update';
      const body = `${initiatorFirstName} is removing you from their Trusted Circle. This will complete in 3 days. Tap to view details.`;

      // 1. Send FCM push notification
      const userDoc = await db.collection('users').doc(recipientUid).get();
      const fcmToken = userDoc.exists ? userDoc.data().fcm_token : null;
      if (fcmToken) {
        try {
          await admin.messaging().send({
            token: fcmToken,
            notification: { title, body },
            data: {
              type: 'pending_deletion',
              requestId: docId,
              click_action: 'FLUTTER_NOTIFICATION_CLICK'
            }
          });
        } catch (err) {
          console.error('Error sending FCM push for pending deletion:', err);
        }
      }

      // 2. Write notification document
      await db.collection('users').doc(recipientUid).collection('notifications').add({
        title,
        body,
        notification_type: 'pending_deletion',
        request_id: docId,
        created_at: admin.firestore.FieldValue.serverTimestamp(),
        read: false
      });

      // 3. Mark notified_of_deletion as true
      return change.after.ref.update({ notified_of_deletion: true });
    }
    return null;
  });

// Triggers on document update in trusted_circle_requests when status changes from pending_deletion back to accepted
exports.onDeletionCancelled = functions.firestore
  .document('trusted_circle_requests/{docId}')
  .onUpdate(async (change, context) => {
    const beforeData = change.before.data();
    const afterData = change.after.data();

    if (!afterData) return null;
    if (beforeData.status === 'pending_deletion' && afterData.status === 'accepted') {
      const docId = context.params.docId;
      const prevInitiatorUid = beforeData.deletion_initiated_by || beforeData.requester_uid;
      const targetUid = (beforeData.requester_uid === prevInitiatorUid) ? beforeData.recipient_uid : beforeData.requester_uid;

      if (!targetUid) return null;

      let initiatorFirstName = 'A trusted contact';
      if (prevInitiatorUid === beforeData.requester_uid) {
        initiatorFirstName = beforeData.requester_first_name || 'Someone';
      } else {
        initiatorFirstName = beforeData.recipient_first_name || 'Someone';
      }

      const title = 'Trusted Circle Update';
      const body = `${initiatorFirstName} has cancelled your removal. You remain in their Trusted Circle.`;

      // 1. Send FCM push notification
      const userDoc = await db.collection('users').doc(targetUid).get();
      const fcmToken = userDoc.exists ? userDoc.data().fcm_token : null;
      if (fcmToken) {
        try {
          await admin.messaging().send({
            token: fcmToken,
            notification: { title, body },
            data: {
              type: 'deletion_cancelled',
              requestId: docId,
              click_action: 'FLUTTER_NOTIFICATION_CLICK'
            }
          });
        } catch (err) {
          console.error('Error sending FCM push for deletion cancellation:', err);
        }
      }

      // 2. Write notification document
      await db.collection('users').doc(targetUid).collection('notifications').add({
        title,
        body,
        notification_type: 'deletion_cancelled',
        request_id: docId,
        created_at: admin.firestore.FieldValue.serverTimestamp(),
        read: false
      });
    }
    return null;
  });

// Scheduled function running every hour to process expired pending deletions after 72 hours
exports.processPendingDeletions = functions.pubsub.schedule('every 1 hours')
  .timeZone('Africa/Lagos')
  .onRun(async (context) => {
    const now = admin.firestore.Timestamp.now();
    console.log(`Processing pending trusted circle deletions at: ${now.toDate().toISOString()}`);

    try {
      const snap = await db.collection('trusted_circle_requests')
        .where('status', '==', 'pending_deletion')
        .where('deletion_scheduled_for', '<=', now)
        .where('deletion_cancelled', '==', false)
        .get();

      if (snap.empty) {
        console.log('No expired pending deletion requests found.');
        return null;
      }

      for (const doc of snap.docs) {
        const data = doc.data();
        const reqUid = data.requester_uid;
        const recUid = data.recipient_uid;
        const initiatorUid = data.deletion_initiated_by || reqUid;
        const targetUid = (reqUid === initiatorUid) ? recUid : reqUid;

        const reqFirstName = data.requester_first_name || 'Someone';
        const recFirstName = data.recipient_first_name || 'Someone';
        const initiatorFirstName = (initiatorUid === reqUid) ? reqFirstName : recFirstName;
        const targetFirstName = (initiatorUid === reqUid) ? recFirstName : reqFirstName;

        // 1. Send FCM to removed user
        const targetUserDoc = await db.collection('users').doc(targetUid).get();
        const targetFcmToken = targetUserDoc.exists ? targetUserDoc.data().fcm_token : null;
        if (targetFcmToken) {
          try {
            await admin.messaging().send({
              token: targetFcmToken,
              notification: {
                title: 'Trusted Circle Update',
                body: `You have been removed from ${initiatorFirstName}'s Trusted Circle. The connection is now closed.`
              }
            });
          } catch (err) {
            console.error(`Error sending FCM to target user ${targetUid}:`, err);
          }
        }

        // 2. Send FCM to initiator user
        const initiatorUserDoc = await db.collection('users').doc(initiatorUid).get();
        const initiatorFcmToken = initiatorUserDoc.exists ? initiatorUserDoc.data().fcm_token : null;
        if (initiatorFcmToken) {
          try {
            await admin.messaging().send({
              token: initiatorFcmToken,
              notification: {
                title: 'Trusted Circle Update',
                body: `${targetFirstName} has been removed from your Trusted Circle.`
              }
            });
          } catch (err) {
            console.error(`Error sending FCM to initiator user ${initiatorUid}:`, err);
          }
        }

        // 3. Write notification documents to both users
        await db.collection('users').doc(targetUid).collection('notifications').add({
          title: 'Trusted Circle Update',
          body: `You have been removed from ${initiatorFirstName}'s Trusted Circle. The connection is now closed.`,
          notification_type: 'deletion_completed',
          created_at: admin.firestore.FieldValue.serverTimestamp(),
          read: false
        });

        await db.collection('users').doc(initiatorUid).collection('notifications').add({
          title: 'Trusted Circle Update',
          body: `${targetFirstName} has been removed from your Trusted Circle.`,
          notification_type: 'deletion_completed',
          created_at: admin.firestore.FieldValue.serverTimestamp(),
          read: false
        });

        // 4. Decrement accepted_contacts_count by 1 on both users (clamped at 0)
        const updateCount = async (uId) => {
          const uRef = db.collection('users').doc(uId);
          await db.runTransaction(async (tx) => {
            const uSnap = await tx.get(uRef);
            if (uSnap.exists) {
              const currentCount = uSnap.data().accepted_contacts_count || 0;
              const newCount = Math.max(0, currentCount - 1);
              tx.update(uRef, { accepted_contacts_count: newCount });
            }
          });
        };

        if (reqUid) await updateCount(reqUid);
        if (recUid) await updateCount(recUid);

        // 5. Delete document permanently
        await doc.ref.delete();
        console.log(`Completed 3-day deletion for request: ${doc.id}`);
      }

      return null;
    } catch (error) {
      console.error('Error executing processPendingDeletions:', error);
      throw error;
    }
  });

// 1. generateNearbyAlertId
exports.generateNearbyAlertId = functions.firestore.document('users/{userId}').onCreate(async (snap, context) => {
  const data = snap.data();
  if (data && (data.nearby_alert_id || data.nearbyAlertId)) {
    return null;
  }
  
  const usersRef = db.collection('users');
  let uniqueId = '';
  let collision = true;
  
  while (collision) {
    const randomDigits = Math.floor(10000000 + Math.random() * 90000000); // 8 random digits
    uniqueId = `NA${randomDigits}`;
    
    const query = await usersRef.where('nearby_alert_id', '==', uniqueId).limit(1).get();
    if (query.empty) {
      collision = false;
    }
  }
  
  await snap.ref.update({
    nearby_alert_id: uniqueId,
    nearbyAlertId: uniqueId // camelCase fallback
  });
  console.log(`Generated unique nearby_alert_id ${uniqueId} for user ${context.params.userId}`);
  return null;
});

// Helper for Haversine distance in meters
function getDistance(lat1, lon1, lat2, lon2) {
  const R = 6371000; // Earth radius in meters
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLon = (lon2 - lon1) * Math.PI / 180;
  const a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
            Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
            Math.sin(dLon / 2) * Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

async function runDistanceCheck() {
  const connectionsSnap = await db.collection('nearby_connections').where('status', 'in', ['active', 'expiring', 'accepted']).get();
  if (connectionsSnap.empty) return;

  const messaging = admin.messaging();

  for (const doc of connectionsSnap.docs) {
    const conn = doc.data();
    const requesterUid = conn.requester_uid;
    const recipientUid = conn.recipient_uid;

    const requesterSession = await db.collection('nearby_sessions').doc(requesterUid).get();
    const recipientSession = await db.collection('nearby_sessions').doc(recipientUid).get();

    if (!requesterSession.exists || !recipientSession.exists) {
      // If session is deleted, transition connection to expired
      await doc.ref.update({ status: 'expired' });
      continue;
    }

    const rSess = requesterSession.data();
    const pSess = recipientSession.data();

    if (!rSess.is_active || !pSess.is_active) {
      await doc.ref.update({ status: 'expired' });
      continue;
    }

    const rLat = rSess.lat;
    const rLng = rSess.lng;
    const pLat = pSess.lat;
    const pLng = pSess.lng;

    const distance = getDistance(rLat, rLng, pLat, pLng);
    const radius = Math.min(rSess.radius_metres || 20, pSess.radius_metres || 20);

    let newStatus = 'active';
    if (distance > radius) {
      newStatus = 'expired';
    } else if (distance >= radius * 0.8) {
      newStatus = 'expiring';
    }

    const updates = {
      last_distance_metres: distance,
      requester_lat: rLat,
      requester_lng: rLng,
      recipient_lat: pLat,
      recipient_lng: pLng
    };

    if (newStatus !== conn.status) {
      updates.status = newStatus;
      
      const payload = {
        notification: {
          title: `Nearby Alert: Proximity ${newStatus === 'expired' ? 'Connection Lost' : 'Warning'}`,
          body: newStatus === 'expired' 
            ? `Connection with ${conn.requester_name === rSess.first_name ? conn.recipient_name : conn.requester_name} was lost.`
            : `You are approaching the radius limit with ${conn.requester_name === rSess.first_name ? conn.recipient_name : conn.requester_name}.`
        }
      };

      try {
        const reqUser = await db.collection('users').doc(requesterUid).get();
        const recUser = await db.collection('users').doc(recipientUid).get();

        const tokens = [];
        if (reqUser.exists && reqUser.data().fcm_token) tokens.push(reqUser.data().fcm_token);
        if (reqUser.exists && reqUser.data().fcmToken) tokens.push(reqUser.data().fcmToken);
        if (recUser.exists && recUser.data().fcm_token) tokens.push(recUser.data().fcm_token);
        if (recUser.exists && recUser.data().fcmToken) tokens.push(recUser.data().fcmToken);

        // Unique tokens
        const uniqueTokens = [...new Set(tokens)];

        if (uniqueTokens.length > 0) {
          await messaging.sendEachForMulticast({ tokens: uniqueTokens, notification: payload.notification });
        }
      } catch (err) {
        console.error('Error sending distance FCM:', err);
      }
    }

    await doc.ref.update(updates);
  }
}

// 2. updateConnectionDistances
exports.updateConnectionDistances = functions.pubsub.schedule('every 1 minutes').onRun(async (context) => {
  await runDistanceCheck();
  await new Promise(resolve => setTimeout(resolve, 30000));
  await runDistanceCheck();
  return null;
});

// 3. connectionRequestNotification
exports.connectionRequestNotification = functions.firestore.document('nearby_connections/{connectionId}').onCreate(async (snap, context) => {
  const data = snap.data();
  if (!data || data.status !== 'pending') return null;

  const recipientUid = data.recipient_uid;
  const requesterName = data.requester_name;
  const connType = data.connection_type;

  const recipientDoc = await db.collection('users').doc(recipientUid).get();
  if (!recipientDoc.exists) return null;

  const rData = recipientDoc.data();
  const token = rData.fcm_token || rData.fcmToken;
  if (!token) {
    console.log(`No FCM token found for recipient ${recipientUid}`);
    return null;
  }

  const firstName = requesterName.split(' ')[0];
  const message = {
    token: token,
    notification: {
      title: 'New Nearby Alert Connection Request',
      body: `${firstName} wants to connect with you as ${connType}.`
    },
    data: {
      connectionId: context.params.connectionId,
      click_action: 'FLUTTER_NOTIFICATION_CLICK',
      screen: 'nearby_alert'
    }
  };

  try {
    await admin.messaging().send(message);
    console.log(`Sent connection request notification to ${recipientUid}`);
  } catch (err) {
    console.error('Error sending request notification:', err);
  }
  return null;
});

// 4. cleanupExpiredSessions
exports.cleanupExpiredSessions = functions.pubsub.schedule('every 10 minutes').onRun(async (context) => {
  const now = admin.firestore.Timestamp.now();
  const expiredSessionsSnap = await db.collection('nearby_sessions').where('expires_at', '<', now).get();
  if (expiredSessionsSnap.empty) {
    console.log('No expired sessions found to clean.');
    return null;
  }

  const batch = db.batch();
  const expiredUids = [];

  expiredSessionsSnap.docs.forEach((doc) => {
    batch.delete(doc.ref);
    expiredUids.push(doc.id);
  });

  await batch.commit();
  console.log(`Cleaned up ${expiredSessionsSnap.size} expired sessions.`);

  if (expiredUids.length > 0) {
    // Transition connections belonging to these sessions to expired
    const connectionsSnap = await db.collection('nearby_connections')
      .where('status', 'in', ['active', 'expiring'])
      .get();

    for (const doc of connectionsSnap.docs) {
      const conn = doc.data();
      if (expiredUids.includes(conn.requester_uid) || expiredUids.includes(conn.recipient_uid)) {
        await doc.ref.update({ status: 'expired' });
      }
    }
  }

  return null;
});

// 5. onPanicTriggered
exports.onPanicTriggered = functions.firestore.document('active_panics/{panicId}').onCreate(async (snap, context) => {
  const panic = snap.data();
  if (!panic || !panic.is_active) return null;

  const notifiedContacts = panic.notified_contacts || [];
  if (notifiedContacts.length === 0) return null;

  const messaging = admin.messaging();

  for (const contactUid of notifiedContacts) {
    const contactDoc = await db.collection('users').doc(contactUid).get();
    if (!contactDoc.exists) continue;

    const cData = contactDoc.data();
    const token = cData.fcm_token || cData.fcmToken;
    if (!token) continue;

    const message = {
      token: token,
      android: {
        priority: 'high'
      },
      data: {
        interrupt: 'true',
        victim_uid: panic.uid,
        victim_first_name: panic.first_name,
        victim_last_name: panic.last_name,
        victim_lat: String(panic.lat),
        victim_lng: String(panic.lng),
        victim_address: panic.address || '',
        sent_at: String(Date.now())
      }
    };

    try {
      await messaging.send(message);
      console.log(`Sent panic FCM interrupt to contact ${contactUid}`);
    } catch (err) {
      console.error(`Error sending panic FCM to contact ${contactUid}:`, err);
    }
  }

  return null;
});

// 6. onNearbyConnectionAccepted & Declined
exports.onNearbyConnectionStatusChange = functions.firestore.document('nearby_connections/{connectionId}').onUpdate(async (change, context) => {
  const before = change.before.data();
  const after = change.after.data();

  if (!before || !after) return null;

  if (before.status !== 'accepted' && after.status === 'accepted') {
    const connId = context.params.connectionId;
    const reqUid = after.requester_uid;
    const recUid = after.recipient_uid;

    console.log(`Nearby Connection ${connId} accepted between ${reqUid} and ${recUid}`);
    
    // Always transition transient 'accepted' status to 'active' for proximity tracking
    await change.after.ref.update({ status: 'active' });

    // Check if nearby_alert_events record already written
    const existingEvent = await db.collection('nearby_alert_events').where('connection_id', '==', connId).get();
    if (!existingEvent.empty) {
      console.log(`nearby_alert_events record already exists for ${connId}`);
      return null;
    }

    // Step 1: Collect locations
    let reqLat = after.requester_lat || 6.5244;
    let reqLng = after.requester_lng || 3.3792;
    let reqAddr = after.requester_address || "";

    let recLat = after.recipient_lat || 6.5244;
    let recLng = after.recipient_lng || 3.3792;
    let recAddr = after.recipient_address || "";

    const reqUser = await db.collection('users').doc(reqUid).get();
    let reqFirstName = after.requester_name || "User";
    let reqLastName = "";
    if (reqUser.exists) {
      const d = reqUser.data();
      reqFirstName = d.first_name || d.firstName || reqFirstName;
      reqLastName = d.last_name || d.lastName || "";
      reqLat = d.last_known_lat || d.lat || reqLat;
      reqLng = d.last_known_lng || d.lng || reqLng;
      reqAddr = reqAddr || d.last_known_address || d.address || `${reqLat.toFixed(6)}, ${reqLng.toFixed(6)}`;
    } else if (!reqAddr) {
      reqAddr = `${reqLat.toFixed(6)}, ${reqLng.toFixed(6)}`;
    }

    const recUser = await db.collection('users').doc(recUid).get();
    let recFirstName = after.recipient_name || "User";
    let recLastName = "";
    if (recUser.exists) {
      const d = recUser.data();
      recFirstName = d.first_name || d.firstName || recFirstName;
      recLastName = d.last_name || d.lastName || "";
      recLat = d.last_known_lat || d.lat || recLat;
      recLng = d.last_known_lng || d.lng || recLng;
      recAddr = recAddr || d.last_known_address || d.address || `${recLat.toFixed(6)}, ${recLng.toFixed(6)}`;
    } else if (!recAddr) {
      recAddr = `${recLat.toFixed(6)}, ${recLng.toFixed(6)}`;
    }

    const expiresAt = new Date();
    expiresAt.setDate(expiresAt.getDate() + 7);

    // Step 2: Write location_history for both users
    await db.collection('users').doc(reqUid).collection('location_history').add({
      lat: reqLat,
      lng: reqLng,
      address: reqAddr,
      note: 'Connected via Nearby Alert',
      created_at: admin.firestore.FieldValue.serverTimestamp(),
      expires_at: admin.firestore.Timestamp.fromDate(expiresAt),
      source: 'nearby_alert',
      tag_label: 'Nearby Alert',
      tag_color: '6C3FC4',
    });

    await db.collection('users').doc(recUid).collection('location_history').add({
      lat: recLat,
      lng: recLng,
      address: recAddr,
      note: 'Connected via Nearby Alert',
      created_at: admin.firestore.FieldValue.serverTimestamp(),
      expires_at: admin.firestore.Timestamp.fromDate(expiresAt),
      source: 'nearby_alert',
      tag_label: 'Nearby Alert',
      tag_color: '6C3FC4',
    });

    // Step 3: Collect visible_to array
    const visibleTo = new Set([reqUid, recUid]);
    const reqTrusted = await db.collection('trusted_circle_requests').where('status', '==', 'accepted').get();
    reqTrusted.docs.forEach((doc) => {
      const data = doc.data();
      if (data.requester_uid === reqUid && data.recipient_uid) visibleTo.add(data.recipient_uid);
      if (data.recipient_uid === reqUid && data.requester_uid) visibleTo.add(data.requester_uid);
      if (data.requester_uid === recUid && data.recipient_uid) visibleTo.add(data.recipient_uid);
      if (data.recipient_uid === recUid && data.requester_uid) visibleTo.add(data.requester_uid);
    });

    const visibleToList = Array.from(visibleTo);

    const eventDoc = await db.collection('nearby_alert_events').add({
      connection_id: connId,
      requester_uid: reqUid,
      requester_first_name: reqFirstName,
      requester_last_name: reqLastName,
      requester_lat: reqLat,
      requester_lng: reqLng,
      requester_address: reqAddr,
      recipient_uid: recUid,
      recipient_first_name: recFirstName,
      recipient_last_name: recLastName,
      recipient_lat: recLat,
      recipient_lng: recLng,
      recipient_address: recAddr,
      status: 'accepted',
      connected_at: admin.firestore.FieldValue.serverTimestamp(),
      visible_to: visibleToList,
    });

    // Step 4: Send FCM notifications
    const now = new Date();
    const timeStr = `${String(now.getHours()).padStart(2, '0')}:${String(now.getMinutes()).padStart(2, '0')}`;
    
    for (const contactUid of visibleToList) {
      if (contactUid === reqUid || contactUid === recUid) continue;
      const cDoc = await db.collection('users').doc(contactUid).get();
      if (!cDoc.exists) continue;
      const token = cDoc.data().fcm_token || cDoc.data().fcmToken;
      if (token) {
        try {
          await admin.messaging().send({
            token: token,
            notification: {
              title: 'Nearby Alert Connection',
              body: `${reqFirstName} and ${recFirstName} connected via Nearby Alert at ${timeStr}`
            },
            data: {
              nearby_alert_event_id: eventDoc.id
            }
          });
        } catch (e) {
          console.error(`Error sending FCM to ${contactUid}:`, e);
        }
      }
    }
  } else if (before.status !== 'declined' && after.status === 'declined') {
    const connId = context.params.connectionId;
    const reqUid = after.requester_uid;
    const recUid = after.recipient_uid;

    await db.collection('nearby_alert_events').add({
      connection_id: connId,
      requester_uid: reqUid,
      requester_first_name: after.requester_name || "User",
      requester_last_name: "",
      requester_lat: after.requester_lat || 0.0,
      requester_lng: after.requester_lng || 0.0,
      requester_address: "",
      recipient_uid: recUid,
      recipient_first_name: after.recipient_name || "User",
      recipient_last_name: "",
      recipient_lat: after.recipient_lat || 0.0,
      recipient_lng: after.recipient_lng || 0.0,
      recipient_address: "",
      status: 'declined',
      connected_at: admin.firestore.FieldValue.serverTimestamp(),
      visible_to: [reqUid, recUid],
    });
  }

  return null;
});

// 7. welfareCheckMigration
exports.welfareCheckMigration = functions.https.onRequest(async (req, res) => {
  try {
    const reqSnap = await db.collection('trusted_circle_requests').where('welfare_check_enabled', '==', false).get();
    const batch = db.batch();
    reqSnap.docs.forEach((doc) => {
      batch.update(doc.ref, { welfare_check_enabled: true });
    });
    await batch.commit();
    res.status(200).send(`Successfully updated ${reqSnap.size} trusted_circle_requests documents to welfare_check_enabled = true`);
  } catch (err) {
    res.status(500).send(`Migration error: ${err.message}`);
  }
});

// 8. communityNoteCleanup (running every 24 hours)
exports.communityNoteCleanup = functions.pubsub.schedule('0 0 * * *')
  .timeZone('Africa/Lagos')
  .onRun(async (context) => {
    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

    const oldNotesSnap = await db.collection('community_notes')
      .where('created_at', '<', admin.firestore.Timestamp.fromDate(thirtyDaysAgo))
      .get();

    if (oldNotesSnap.empty) {
      console.log('No community notes older than 30 days to delete.');
      return null;
    }

    const batch = db.batch();
    oldNotesSnap.docs.forEach((doc) => {
      batch.delete(doc.ref);
    });

    await batch.commit();
    console.log(`Cleaned up ${oldNotesSnap.size} community notes older than 30 days.`);
    return null;
  });

// 9. onTrustedCircleRequestWrite (Denormalized accepted_contacts_count sync)
exports.onTrustedCircleRequestWrite = functions.firestore
  .document('trusted_circle_requests/{docId}')
  .onWrite(async (change, context) => {
    const beforeData = change.before.exists ? change.before.data() : null;
    const afterData = change.after.exists ? change.after.data() : null;

    const wasAccepted = beforeData && beforeData.status === 'accepted';
    const isAccepted = afterData && afterData.status === 'accepted';

    if (wasAccepted === isAccepted) {
      return null;
    }

    const reqUid = (afterData ? afterData.requester_uid : beforeData ? beforeData.requester_uid : '') || '';
    const recUid = (afterData ? afterData.recipient_uid : beforeData ? beforeData.recipient_uid : '') || '';

    const delta = (!wasAccepted && isAccepted) ? 1 : -1;

    const updateCount = async (uid) => {
      if (!uid) return;
      const userRef = db.collection('users').doc(uid);
      await db.runTransaction(async (transaction) => {
        const userDoc = await transaction.get(userRef);
        if (!userDoc.exists) return;
        const currentCount = (userDoc.data().accepted_contacts_count || 0);
        const newCount = Math.max(0, currentCount + delta);
        transaction.update(userRef, { accepted_contacts_count: newCount });
      });
    };

    await Promise.all([updateCount(reqUid), updateCount(recUid)]);
    return null;
  });

// ─── AI Community Safety Summary Function ──────────────────────────────────

function calculateHaversineDistanceKm(lat1, lon1, lat2, lon2) {
  const p = 0.017453292519943295; // Math.PI / 180
  const a = 0.5 - Math.cos((lat2 - lat1) * p) / 2 +
      Math.cos(lat1 * p) * Math.cos(lat2 * p) * (1 - Math.cos((lon2 - lon1) * p)) / 2;
  return 12742 * Math.asin(Math.sqrt(a)); // 2 * R; R = 6371 km
}

exports.getCommunitySafetySummary = functions.https.onCall(async (data, context) => {
  // Step 1 — Authentication Check
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'User must be authenticated to request safety summaries.'
    );
  }

  const lat = parseFloat(data.lat);
  const lng = parseFloat(data.lng);
  const radiusKm = parseFloat(data.radius_km || 12.0);
  const bypassCache = Boolean(data.bypass_cache || false);
  const isPreview = Boolean(data.is_preview || false);

  if (isNaN(lat) || isNaN(lng)) {
    throw new functions.https.HttpsError('invalid-argument', 'Valid latitude and longitude are required.');
  }

  try {
    // Step 2 — Fetch notes from Firestore (visible & last 48 hours)
    const fortyEightHoursAgo = new Date(Date.now() - 48 * 60 * 60 * 1000);
    const notesSnap = await db.collection('community_notes')
      .where('is_visible', '==', true)
      .where('created_at', '>=', admin.firestore.Timestamp.fromDate(fortyEightHoursAgo))
      .orderBy('created_at', 'desc')
      .limit(100)
      .get();

    const matchingNotes = [];
    notesSnap.docs.forEach((doc) => {
      const nData = doc.data();
      const nLat = parseFloat(nData.lat || 0.0);
      const nLng = parseFloat(nData.lng || 0.0);
      if (nLat === 0.0 && nLng === 0.0) return;

      const dist = calculateHaversineDistanceKm(lat, lng, nLat, nLng);
      if (dist <= radiusKm) {
        matchingNotes.push({
          id: doc.id,
          address: nData.address || 'Unknown area',
          note: nData.note || '',
          created_at: nData.created_at ? nData.created_at.toDate() : new Date(),
        });
      }
    });

    // If zero notes found within radius
    if (matchingNotes.length === 0) {
      return {
        safety_level: null,
        summary: null,
        key_concerns: [],
        note_count: 0,
        generated_at: new Date().toISOString(),
        message: 'No community notes found in this area.',
      };
    }

    const docId = `${lat.toFixed(3)}_${lng.toFixed(3)}_${Math.round(radiusKm)}`;
    const cacheRef = db.collection('ai_summaries').doc(docId);

    // Step 3 — Check Cache (30 min cache)
    if (!bypassCache) {
      const cacheDoc = await cacheRef.get();
      if (cacheDoc.exists) {
        const cached = cacheDoc.data();
        const genTime = cached.generated_at ? cached.generated_at.toDate().getTime() : 0;
        const ageMinutes = (Date.now() - genTime) / (1000 * 60);

        if (ageMinutes < 30) {
          // Log cache hit usage
          await db.collection('gemini_usage').add({
            called_at: admin.firestore.FieldValue.serverTimestamp(),
            note_count: cached.note_count || matchingNotes.length,
            estimated_tokens: 0,
            cache_hit: true,
            location: new admin.firestore.GeoPoint(lat, lng),
          });

          return {
            safety_level: cached.safety_level || 'Unknown',
            summary: cached.summary || '',
            key_concerns: cached.key_concerns || [],
            note_count: cached.note_count || matchingNotes.length,
            generated_at: cached.generated_at ? cached.generated_at.toDate().toISOString() : new Date().toISOString(),
          };
        }
      }
    }

    // Max limit: 20 notes for preview, 50 notes for full summary
    const maxNotesLimit = isPreview ? 20 : 50;
    const notesToSummarize = matchingNotes.slice(0, maxNotesLimit);

    // Step 4 — Build Prompt for Gemini
    const now = new Date();
    let promptNotesText = notesToSummarize.map((n, idx) => {
      const diffMs = now.getTime() - n.created_at.getTime();
      const diffMins = Math.floor(diffMs / (1000 * 60));
      const diffHours = Math.floor(diffMins / 60);
      let timeAgo = `${diffMins} minutes ago`;
      if (diffHours >= 1) {
        timeAgo = `${diffHours} hours ago`;
      }
      return `${idx + 1}. Address: ${n.address} | Note: "${n.note}" | Posted: ${timeAgo}`;
    }).join('\n');

    if (matchingNotes.length > maxNotesLimit) {
      promptNotesText += `\nNote: There are additional notes not shown here, indicating this is a busy area.`;
    }

    const systemContext = `You are a community safety analyst for SafeTrace, a personal safety app used in Nigeria. You have been given a list of community safety notes submitted by users within a 12 kilometre radius of a specific location. Your job is to analyse these notes and produce a brief, honest safety summary for this area. Be direct and accurate. Do not be unnecessarily alarming but do not minimise real dangers. Use plain language that a regular person can understand.`;

    const instructions = `Based on these notes give me a safety summary in exactly 3 parts. Part 1 is the Overall Safety Level which must be exactly one of these words: Safe, Moderate, Caution, or Danger. Part 2 is the Summary which is 2 to 3 sentences describing the current situation in this area based on the notes. Part 3 is the Key Concerns which is a bullet list of up to 3 specific issues mentioned in the notes. If there are no concerning notes in Part 3 write None reported. Format your response as JSON with keys safety_level, summary, and key_concerns where key_concerns is an array of strings.`;

    const fullPrompt = `${systemContext}\n\nCOMMUNITY NOTES:\n${promptNotesText}\n\n${instructions}`;

    // Step 5 — Call Gemini API
    const apiKey = functions.config().gemini?.api_key || process.env.GEMINI_API_KEY || "AIzaSyD4oAVDWNfX2bYRjBaMQW9ymKuOIHve6pU";
    const geminiUrl = `https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=${apiKey}`;

    const requestBody = JSON.stringify({
      contents: [
        {
          role: 'user',
          parts: [{ text: fullPrompt }]
        }
      ],
      generationConfig: {
        temperature: 0.3,
        maxOutputTokens: 500,
        responseMimeType: 'application/json'
      }
    });

    const https = require('https');
    const url = require('url');

    const callGeminiHttp = (targetUrl, bodyStr) => {
      return new Promise((resolve, reject) => {
        const parsedUrl = url.parse(targetUrl);
        const req = https.request({
          hostname: parsedUrl.hostname,
          path: parsedUrl.path,
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Content-Length': Buffer.byteLength(bodyStr)
          }
        }, (res) => {
          let responseData = '';
          res.on('data', (chunk) => { responseData += chunk; });
          res.on('end', () => {
            if (res.statusCode >= 200 && res.statusCode < 300) {
              resolve(responseData);
            } else {
              reject(new Error(`Gemini API HTTP Error ${res.statusCode}: ${responseData}`));
            }
          });
        });
        req.on('error', (err) => reject(err));
        req.write(bodyStr);
        req.end();
      });
    };

    let geminiResponseJsonText = null;
    try {
      const rawRes = await callGeminiHttp(geminiUrl, requestBody);
      const parsedRes = JSON.parse(rawRes);
      if (parsedRes.candidates && parsedRes.candidates.length > 0 && parsedRes.candidates[0].content) {
        geminiResponseJsonText = parsedRes.candidates[0].content.parts[0].text;
      }
    } catch (apiErr) {
      console.error('Gemini API call failed:', apiErr);
    }

    // Step 6 — Parse Gemini response
    let safetyLevel = 'Unknown';
    let summaryText = 'Unable to generate summary at this time';
    let keyConcerns = [];

    if (geminiResponseJsonText) {
      try {
        let cleanText = geminiResponseJsonText.trim();
        if (cleanText.startsWith('```json')) {
          cleanText = cleanText.replace(/^```json/, '').replace(/```$/, '').trim();
        } else if (cleanText.startsWith('```')) {
          cleanText = cleanText.replace(/^```/, '').replace(/```$/, '').trim();
        }

        const summaryObj = JSON.parse(cleanText);
        const validLevels = ['Safe', 'Moderate', 'Caution', 'Danger'];

        if (summaryObj.safety_level && validLevels.includes(summaryObj.safety_level)) {
          safetyLevel = summaryObj.safety_level;
        }

        if (summaryObj.summary && typeof summaryObj.summary === 'string') {
          summaryText = summaryObj.summary;
        }

        if (Array.isArray(summaryObj.key_concerns)) {
          keyConcerns = summaryObj.key_concerns.map(c => String(c)).slice(0, 3);
        }
      } catch (parseErr) {
        console.error('Failed to parse Gemini JSON output:', parseErr, geminiResponseJsonText);
      }
    }

    // Step 7 — Cache the result in ai_summaries
    const resultToStore = {
      safety_level: safetyLevel,
      summary: summaryText,
      key_concerns: keyConcerns,
      generated_at: admin.firestore.FieldValue.serverTimestamp(),
      note_count: matchingNotes.length,
      lat: lat,
      lng: lng,
      radius_km: radiusKm,
    };

    await cacheRef.set(resultToStore);

    // Step 8 — Log Usage to gemini_usage
    const estimatedTokens = Math.round(fullPrompt.length / 4);
    await db.collection('gemini_usage').add({
      called_at: admin.firestore.FieldValue.serverTimestamp(),
      note_count: matchingNotes.length,
      estimated_tokens: estimatedTokens,
      cache_hit: false,
      location: new admin.firestore.GeoPoint(lat, lng),
    });

    return {
      safety_level: safetyLevel,
      summary: summaryText,
      key_concerns: keyConcerns,
      note_count: matchingNotes.length,
      generated_at: new Date().toISOString(),
    };

  } catch (error) {
    console.error('Error executing getCommunitySafetySummary function:', error);
    return {
      safety_level: 'Unknown',
      summary: 'Unable to generate summary at this time',
      key_concerns: [],
      note_count: 0,
      generated_at: new Date().toISOString(),
      error: error.message,
    };
  }
});

// Scheduled function running every 6 hours to clean up ai_summaries older than 24 hours
exports.cleanupAiSummaries = functions.pubsub.schedule('0 */6 * * *')
  .onRun(async (context) => {
    const twentyFourHoursAgo = new Date(Date.now() - 24 * 60 * 60 * 1000);
    console.log(`Starting cleanup of ai_summaries older than ${twentyFourHoursAgo.toISOString()}`);
    try {
      const oldSnap = await db.collection('ai_summaries')
        .where('generated_at', '<', admin.firestore.Timestamp.fromDate(twentyFourHoursAgo))
        .get();

      if (oldSnap.empty) {
        console.log('No stale ai_summaries found.');
        return null;
      }

      const batch = db.batch();
      oldSnap.docs.forEach((doc) => {
        batch.delete(doc.ref);
      });
      await batch.commit();
      console.log(`Successfully deleted ${oldSnap.size} stale ai_summaries documents.`);
      return null;
    } catch (err) {
      console.error('Error cleaning up ai_summaries:', err);
      throw err;
    }
  });// ─────────────────────────────────────────────────────────────────────────────
// ─────────────────────────────────────────────────────────────────────────────
// verifyPaystackPayment — Verify Paystack transaction and activate Plus plan
// ─────────────────────────────────────────────────────────────────────────────
const https = require('https');

exports.verifyPaystackPayment = functions.region('europe-west3').https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be signed in.');
  }

  const { reference } = data || {};
  if (!reference || typeof reference !== 'string') {
    throw new functions.https.HttpsError('invalid-argument', 'A valid Paystack reference is required.');
  }

  const paystackSecretKey = process.env.PAYSTACK_SECRET_KEY || '';
  const uid = context.auth.uid;

  // Call Paystack verify endpoint
  let paystackResponse;
  try {
    paystackResponse = await new Promise((resolve, reject) => {
      const options = {
        hostname: 'api.paystack.co',
        port: 443,
        path: `/transaction/verify/${encodeURIComponent(reference)}`,
        method: 'GET',
        headers: {
          Authorization: `Bearer ${paystackSecretKey}`,
          'Content-Type': 'application/json',
        },
      };

      const req = https.request(options, (res) => {
        let body = '';
        res.on('data', (chunk) => { body += chunk; });
        res.on('end', () => {
          try {
            resolve(JSON.parse(body));
          } catch (e) {
            reject(new Error('Failed to parse Paystack response'));
          }
        });
      });
      req.on('error', reject);
      req.end();
    });
  } catch (err) {
    console.error('[PAYSTACK] Verification HTTP error:', err);
    throw new functions.https.HttpsError('internal', 'Failed to reach Paystack servers.');
  }

  const tx = paystackResponse && paystackResponse.data;
  if (!paystackResponse.status || !tx) {
    console.error('[PAYSTACK] Bad response:', JSON.stringify(paystackResponse));
    throw new functions.https.HttpsError('internal', 'Paystack verification failed.');
  }

  if (tx.status !== 'success') {
    throw new functions.https.HttpsError('failed-precondition', `Payment not successful. Status: ${tx.status}`);
  }

  // ₦1,999 = 199900 kobo
  const expectedAmount = 199900;
  if (tx.amount < expectedAmount) {
    console.error(`[PAYSTACK] Amount mismatch: got ${tx.amount}, expected ${expectedAmount}`);
    throw new functions.https.HttpsError('failed-precondition', 'Payment amount does not match subscription price.');
  }

  // Check reference not already used (idempotency)
  const existingRef = await db.collection('paystack_transactions').doc(reference).get();
  if (existingRef.exists) {
    console.warn('[PAYSTACK] Reference already used:', reference);
    return { success: true, already_applied: true };
  }

  // Compute subscription expiry (+30 days)
  const now = new Date();
  const expiresAt = new Date(now.getTime() + 30 * 24 * 60 * 60 * 1000);

  const batch = db.batch();

  // Write subscription to user document
  const userRef = db.collection('users').doc(uid);
  batch.set(userRef, {
    subscription_tier: 'plus',
    subscription_active: true,
    subscription_plan: 'SafeTrace Plus',
    subscription_amount: 1999,
    subscription_currency: 'NGN',
    subscription_started_at: admin.firestore.FieldValue.serverTimestamp(),
    subscription_expires_at: admin.firestore.Timestamp.fromDate(expiresAt),
    paystack_reference: reference,
  }, { merge: true });

  // Record transaction (idempotency lock)
  const txRef = db.collection('paystack_transactions').doc(reference);
  batch.set(txRef, {
    uid,
    reference,
    amount: tx.amount,
    currency: tx.currency,
    status: tx.status,
    paid_at: tx.paid_at,
    verified_at: admin.firestore.FieldValue.serverTimestamp(),
    plan: 'SafeTrace Plus',
    expires_at: admin.firestore.Timestamp.fromDate(expiresAt),
  });

  await batch.commit();

  console.log(`[PAYSTACK] Subscription activated for uid=${uid}, ref=${reference}, expires=${expiresAt.toISOString()}`);
  return { success: true, expires_at: expiresAt.toISOString() };
});

// ─────────────────────────────────────────────────────────────────────────────
// cancelSubscription — Mark user subscription as cancelled
// ─────────────────────────────────────────────────────────────────────────────
exports.cancelSubscription = functions.region('europe-west3').https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be signed in.');
  }

  const uid = context.auth.uid;
  await db.collection('users').doc(uid).update({
    subscription_tier: 'free',
    subscription_active: false,
    subscription_cancelled_at: admin.firestore.FieldValue.serverTimestamp(),
  });

  console.log(`[SUBSCRIPTION] Cancelled for uid=${uid}`);
  return { success: true };
});

