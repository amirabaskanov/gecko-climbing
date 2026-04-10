// Shared notification types and route encoding for the iOS payload contract.
export type NotificationCategory = 'social' | 'friends' | 'reminders';

export type NotificationRoute =
  | { kind: 'post'; id: string }
  | { kind: 'profile'; userId: string }
  | { kind: 'session'; id: string }
  | { kind: 'comment'; postId: string; commentId: string };

export interface NotificationPrefs {
  social: boolean;
  friends: boolean;
  reminders: boolean;
}

export interface SendOptions {
  recipientUid: string;
  actorUid?: string;
  category: NotificationCategory;
  title: string;
  body: string;
  route: NotificationRoute;
  bypassQuietHours?: boolean;
  bypassRateLimit?: boolean;
}

export function encodeRoute(route: NotificationRoute): string {
  switch (route.kind) {
    case 'post':
      return `post:${route.id}`;
    case 'profile':
      return `profile:${route.userId}`;
    case 'session':
      return `session:${route.id}`;
    case 'comment':
      return `comment:${route.postId}:${route.commentId}`;
  }
}
