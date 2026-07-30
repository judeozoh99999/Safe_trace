const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

const db = admin.firestore();

// Scheduled function running every day at midnight (00:00 Lagos Time)
exports.purgeOldLocations = functions.pubsub.schedule('0 0 * * *')
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

// Scheduled function running every hour to delete pending trusted circle requests whose 3-day window has expired
exports.purgePendingDeletions = functions.pubsub.schedule('0 * * * *')
  .timeZone('Africa/Lagos')
  .onRun(async (context) => {
    const now = admin.firestore.Timestamp.now();
    console.log(`Checking for expired 3-day trusted circle deletions at: ${now.toDate().toISOString()}`);

    try {
      const snap = await db.collection('trusted_circle_requests')
        .where('deletion_scheduled_for', '<=', now)
        .get();

      if (snap.empty) {
        console.log('No expired deletion requests found.');
        return null;
      }

      const batch = db.batch();
      snap.docs.forEach((doc) => {
        batch.delete(doc.ref);
      });

      await batch.commit();
      console.log(`Purged ${snap.size} expired trusted circle requests.`);
      return null;
    } catch (error) {
      console.error('Error executing purgePendingDeletions:', error);
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
  const connectionsSnap = await db.collection('nearby_connections').where('status', 'in', ['active', 'expiring']).get();
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


