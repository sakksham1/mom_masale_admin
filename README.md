# 🌶️ Mom Masale Admin

![Platform](https://img.shields.io/badge/Platform-Flutter-02569B?logo=flutter)
![Backend](https://img.shields.io/badge/Backend-Workers%20%2B%20D1-f38020)
![State](https://img.shields.io/badge/State-Riverpod-5C6BC0)
![Routing](https://img.shields.io/badge/Routing-go__router-blueviolet)
![Targets](https://img.shields.io/badge/Targets-Android%20%7C%20Windows%20%7C%20Linux%20%7C%20Web-informational)
![License](https://img.shields.io/badge/License-All%20Rights%20Reserved-red)

The internal, role-based operations app for **Mom Masale** — a Flutter ERP client that lets staff manage orders, inventory, the product catalog, sales, packaging, and approvals from a phone, tablet, or desktop, backed by the same Cloudflare Workers + D1 API that powers [mommasale.com](https://mommasale.com).

This is the **staff/admin companion app**, not the customer storefront — see the main [website repo](https://github.com/sakksham1) for that.

---

## About

Mom Masale Admin is a single Flutter codebase that renders a different UI per signed-in role — admin, manager, warehouser, packaging, and salesperson each see only the tabs and actions their role permits, with every write enforced server-side regardless of what the client shows. It's built to run comfortably as a phone app for warehouse/packaging staff and as a desktop app for admins doing day-to-day operations review.

---

## Architecture

**Client**
- Flutter (Material 3, dynamic color) with a hand-tuned spice-tin design language — maroon/turmeric/paprika/cumin/parchment palette, `Fraunces` display type, floating pill-shaped bottom nav with an animated "More" overlay for role-congested tab sets
- **Riverpod** for state — one `Provider` + `FutureProvider` pair per feature (`xApiProvider` / `xProvider`), with `ref.invalidate` used for cache-busting after mutations
- **go_router** for navigation, with a single `redirect` gate enforcing per-role route access (`route_permissions.dart`) and bouncing unauthorized roles back to `/login?denied=1`
- **Dio** + `cookie_jar` for networking, with session cookies (not tokens) persisted via `PersistCookieJar` on native platforms
- **Firebase Cloud Messaging** for push notifications (admin/manager only), with a custom HTTP v1 OAuth2 flow on the Workers side since Cloudflare Workers have no Node runtime for `firebase-admin`

**Backend** (shared with the main site — see [mommasale.com repo](https://github.com/sakksham1))
- **Cloudflare Workers** — role-gated REST endpoints under `/api/admin`, `/api/manager`, `/api/warehouse`, `/api/packaging`, `/api/sales`
- **D1 (SQLite)** — orders, products, raw materials, sessions, push tokens, and a full audit log
- Every write that isn't admin-only goes through an **approval queue** (`manager/approvals`) — warehousers file stock adjustments, managers propose catalog edits, and an admin/manager decides before anything takes effect

**Roles & access**
| Role | Can see | Can write |
|---|---|---|
| **admin** | Everything | Everything, directly |
| **manager** | Dashboard, Business, Catalog, Reviews, Approvals | Proposes catalog/stock changes for approval |
| **warehouser** | Stock (Products + Raw Materials) | Submits stock adjustments for approval |
| **packaging** | Report Packaging, Stock (read-only) | Submits packaging reports for approval |
| **salesperson** | Sales | Submits sale reports |

Role-gating is enforced in two places that must stay in sync: `route_permissions.dart` on the client (controls what's *shown*) and `requireRole` checks in the Workers API (controls what's *allowed*) — the client-side gate is a UX convenience, never the security boundary.

---

## Features

- **Dashboard** — revenue (total/today/month), pending fulfilment, top products, recent orders, and a live audit-log feed
- **Business** — orders (view/edit status & payment), customers (role assignment), staff login history, and a raw-SQL DB Explorer (admin only)
- **Inventory (Stock)** — finished-product and raw-material stock, with warehouser-only adjustment sheets (restock / damaged / correction, or restock / consumption / correction) that route through approvals
- **Catalog** — full product editing (pricing, sizes, image upload, visibility flags, SEO copy), with admin changes going live immediately and manager changes queued for approval
- **Reviews** — pending/approved customer review moderation with image previews, admin-only decisions
- **Approvals** — a unified queue for pending catalog edits, stock adjustments, and packaging reports, with type-specific decision permissions
- **Packaging** — single or bulk packaging report submission with per-size steppers and a persistent history view
- **Sales** — sale report submission and personal sales totals/history
- **Sessions** — view and revoke active login sessions across devices
- **Push notifications** — FCM-backed alerts for new orders, pending approvals, and stock events (admin/manager)

---

## Tech Stack

| Layer | Technology |
|---|---|
| Framework | Flutter (Material 3, dynamic color) |
| State management | flutter_riverpod |
| Routing | go_router |
| Networking | dio, cookie_jar, dio_cookie_manager |
| Push notifications | firebase_core, firebase_messaging, flutter_local_notifications |
| Media | image_picker |
| Backend | Cloudflare Workers + D1 (SQLite) |
| Auth | Server-side session cookies (shared with the main site) |
| Fonts | Fraunces (headings), Manrope (body), IBM Plex Mono (ledger/currency figures) |

---

## Project Structure

```text
mom_masale_admin/
├── lib/
│   ├── main.dart                  entrypoint — theme, router, ProviderScope
│   ├── firebase_options.dart      generated FlutterFire config
│   ├── core/
│   │   ├── auth/                  AppUser, UserRole, AuthController, login screen, route_permissions
│   │   ├── config/                Env (API base URL, dart-define overridable)
│   │   ├── constants/             LayoutConstants (floating nav sizing)
│   │   ├── network/               ApiClient (Dio), ApiException hierarchy, providers
│   │   ├── notifications/         PushNotificationService (FCM)
│   │   ├── theme/                 AppColors, AppTypography, AppTheme, theme mode
│   │   └── utils/                 currency, haptics, platform_name
│   ├── features/
│   │   ├── dashboard/             stats overview
│   │   ├── business/               orders + customers + staff logins tab group
│   │   ├── orders/, customers/
│   │   ├── stock/, warehouse/, products/   inventory (finished goods + raw materials)
│   │   ├── catalog/                admin/manager product editing
│   │   ├── reviews/                review moderation
│   │   ├── approvals/              unified approval queue
│   │   ├── packaging/              packaging report submission + history
│   │   ├── sales/                  sales report submission + history
│   │   ├── sessions/                active session management
│   │   ├── notifications/           notification bell + polling
│   │   ├── db_explorer/            admin-only raw SQL runner
│   │   ├── audit_log/              recent activity feed
│   │   ├── account/                 "Me" screen, quick links, logout
│   │   └── home_shell.dart         app shell — banner, floating nav, "More" popup
│   └── shared/widgets/             AppBanner, TapScale, SuccessPulse, StaggeredFadeIn,
│                                    StatusBadge/RoleAvatar, ProductAvatar, NavMoreSheet
├── android/, windows/, linux/, web/   platform runners
└── pubspec.yaml
```

---

## Design System

- **Palette** — `AppColors.maroon` (primary), `turmeric` (accent), `paprika` (highlight), `cumin` (ink), `parchment`/`charcoal` (light/dark surfaces)
- **Type** — Fraunces for display/headings, Manrope for body copy, IBM Plex Mono for currency and ID figures
- **Motion** — `TapScale` for tactile press feedback, `StaggeredFadeIn` for list entrances, `SuccessPulse` for a full-screen confirmation overlay after key actions, `elasticOut`-staggered popups for the nav's "More" sheet
- **Surfaces** — rounded bottom sheets (`_SheetShell` pattern) in place of plain `AlertDialog`s across adjustment/creation flows

---

## Getting Started

```bash
flutter pub get
flutter run --dart-define=API_BASE_URL=https://mommasale.com
```

Point `API_BASE_URL` at a local/staging Worker during development; it defaults to production. Sign-in is staff-only — customer accounts are rejected at login.

---

## License

This repository is maintained by **Sakksham Enterprises**. All branding, product information, and content are © Mom Masale. Unauthorized commercial reuse is not permitted.

## Author

**Sakksham Srivastava**
Computer Science Engineering student building practical software solutions for real-world businesses.

- Website: https://mommasale.com
- GitHub: https://github.com/sakksham1
