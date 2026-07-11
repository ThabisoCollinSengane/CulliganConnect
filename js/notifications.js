import { supabase } from './supabaseClient.js';

export function requestNotificationPermission() {
  if (!('Notification' in window)) return;
  if (Notification.permission === 'default') {
    Notification.requestPermission();
  }
}

export function showBrowserNotification(title, body) {
  if (!('Notification' in window) || Notification.permission !== 'granted') return;
  try {
    new Notification(title, { body });
  } catch {
    // Some browsers restrict Notification outside a user gesture — safe to ignore.
  }
}

// Subscribes to new notification rows for this user and shows a browser
// notification for each one that arrives while this page is open. The
// subscription only lives as long as the page does — this is a multi-page
// app with full navigations, not a SPA, so there's no cross-page persistence.
export function subscribeToNotifications(userId, onNew) {
  requestNotificationPermission();
  return supabase
    .channel(`notifications:${userId}`)
    .on('postgres_changes', {
      event: 'INSERT',
      schema: 'public',
      table: 'notifications',
      filter: `user_id=eq.${userId}`,
    }, (payload) => {
      showBrowserNotification(payload.new.title, payload.new.body || '');
      if (onNew) onNew(payload.new);
    })
    .subscribe();
}
