// Fast Billing — Admin panel
//
// Static page, no build step: Firebase's modular SDK is loaded straight
// from Google's CDN as ES modules. Talks to the SAME Firestore project as
// the mobile app, so real enforcement of "only admins can read everyone's
// data" lives in firestore.rules (see repo root) — this file's ADMIN_EMAILS
// check is a convenience for the UI only and is NOT itself a security
// boundary (anyone can view page source). Deploy firestore.rules before
// relying on this for anything sensitive.

import { initializeApp } from "https://www.gstatic.com/firebasejs/10.13.2/firebase-app.js";
import {
  getAuth,
  onAuthStateChanged,
  signInWithEmailAndPassword,
  signInWithPopup,
  GoogleAuthProvider,
  signOut,
} from "https://www.gstatic.com/firebasejs/10.13.2/firebase-auth.js";
import {
  getFirestore,
  collection,
  collectionGroup,
  getDocs,
  getCountFromServer,
  getAggregateFromServer,
  sum,
  query,
  orderBy,
  limit,
  doc,
  setDoc,
} from "https://www.gstatic.com/firebasejs/10.13.2/firebase-firestore.js";

// Same config as lib/firebase_options.dart's `web` block — Firebase web API
// keys are not secret (they identify the project, not authorize access);
// real access control is Firestore security rules + this allowlist.
const firebaseConfig = {
  apiKey: "AIzaSyCV2LrFOHOYrUe-Ebq0RGKJpOM50WYwN6w",
  appId: "1:611789051032:web:bca418b0d07314265caced",
  messagingSenderId: "611789051032",
  projectId: "zanvoy-invoices",
  authDomain: "zanvoy-invoices.firebaseapp.com",
  storageBucket: "zanvoy-invoices.firebasestorage.app",
};

// Keep this in sync with the `isAdmin()` allowlist in firestore.rules —
// that's the copy that actually matters for security.
const ADMIN_EMAILS = ["zanjurneanuj@gmail.com"];

const app = initializeApp(firebaseConfig);
const auth = getAuth(app);
const db = getFirestore(app);

// ── Screens ──────────────────────────────────────────────────────────────

const screens = {
  login: document.getElementById("login-screen"),
  denied: document.getElementById("denied-screen"),
  dashboard: document.getElementById("dashboard-screen"),
};

function showScreen(name) {
  for (const key of Object.keys(screens)) {
    screens[key].hidden = key !== name;
  }
}

// ── Auth ─────────────────────────────────────────────────────────────────

const loginForm = document.getElementById("login-form");
const emailInput = document.getElementById("email-input");
const passwordInput = document.getElementById("password-input");
const loginSubmit = document.getElementById("login-submit");
const loginError = document.getElementById("login-error");

loginForm.addEventListener("submit", async (e) => {
  e.preventDefault();
  loginError.hidden = true;
  loginSubmit.disabled = true;
  try {
    await signInWithEmailAndPassword(auth, emailInput.value.trim(), passwordInput.value);
  } catch (err) {
    loginError.textContent = friendlyAuthError(err);
    loginError.hidden = false;
  } finally {
    loginSubmit.disabled = false;
  }
});

document.getElementById("google-signin").addEventListener("click", async () => {
  loginError.hidden = true;
  try {
    await signInWithPopup(auth, new GoogleAuthProvider());
  } catch (err) {
    loginError.textContent = friendlyAuthError(err);
    loginError.hidden = false;
  }
});

document.getElementById("denied-signout").addEventListener("click", () => signOut(auth));
document.getElementById("signout-btn").addEventListener("click", () => signOut(auth));

function friendlyAuthError(err) {
  const code = err?.code || "";
  if (code.includes("wrong-password") || code.includes("invalid-credential")) {
    return "Incorrect email or password.";
  }
  if (code.includes("user-not-found")) return "No account with that email.";
  if (code.includes("too-many-requests")) return "Too many attempts — try again shortly.";
  return err?.message || "Sign-in failed. Please try again.";
}

onAuthStateChanged(auth, (user) => {
  if (!user) {
    showScreen("login");
    loginForm.reset();
    return;
  }
  if (!ADMIN_EMAILS.includes((user.email || "").toLowerCase())) {
    document.getElementById("denied-email").textContent = user.email || "(no email)";
    showScreen("denied");
    return;
  }
  document.getElementById("admin-email").textContent = user.email;
  showScreen("dashboard");
  loadDashboard();
});

// ── Dashboard data ───────────────────────────────────────────────────────

const RECENT_INVOICES_LIMIT = 100;

let allUsers = [];

document.getElementById("refresh-btn").addEventListener("click", loadDashboard);
document.getElementById("user-search").addEventListener("input", (e) => {
  renderUsersTable(filterUsers(e.target.value));
});

async function loadDashboard() {
  setStat("stat-users", "…");
  setStat("stat-invoices", "…");
  setStat("stat-revenue", "…");
  setStat("stat-premium", "…");

  await Promise.all([loadUsers(), loadCounts(), loadRecentInvoices()]);
}

async function loadCounts() {
  try {
    const usersSnap = await getCountFromServer(collection(db, "users"));
    setStat("stat-users", usersSnap.data().count);
  } catch (e) {
    console.error("user count failed", e);
    setStat("stat-users", "—");
  }

  try {
    const invSnap = await getCountFromServer(collectionGroup(db, "invoices"));
    setStat("stat-invoices", invSnap.data().count);
  } catch (e) {
    console.error("invoice count failed", e);
    setStat("stat-invoices", "—");
  }

  try {
    const revSnap = await getAggregateFromServer(collectionGroup(db, "invoices"), {
      revenue: sum("grandTotal"),
    });
    setStat("stat-revenue", formatCurrency(revSnap.data().revenue || 0));
  } catch (e) {
    // Older SDKs / projects without sum() aggregate support — degrade
    // gracefully rather than breaking the whole dashboard.
    console.error("revenue aggregate failed", e);
    setStat("stat-revenue", "—");
  }

  try {
    const subsSnap = await getDocs(collection(db, "subscriptions"));
    const premiumCount = subsSnap.docs.filter((d) => d.data().isPremium === true).length;
    setStat("stat-premium", premiumCount);
  } catch (e) {
    console.error("premium count failed", e);
    setStat("stat-premium", "—");
  }
}

async function loadUsers() {
  const tbody = document.getElementById("users-tbody");
  tbody.innerHTML = `<tr><td colspan="5" class="muted">Loading…</td></tr>`;

  try {
    const [usersSnap, subsSnap] = await Promise.all([
      getDocs(collection(db, "users")),
      getDocs(collection(db, "subscriptions")),
    ]);

    const premiumByUid = new Map();
    subsSnap.docs.forEach((d) => premiumByUid.set(d.id, d.data().isPremium === true));

    const users = usersSnap.docs.map((d) => ({
      uid: d.id,
      name: d.data().displayName || d.data().name || "(no name)",
      email: d.data().email || "—",
      isPremium: premiumByUid.get(d.id) === true,
      invoiceCount: null, // filled in below
    }));

    // Per-user invoice counts. Fine for a small-to-medium user base; if
    // this ever gets slow, replace with a denormalized counter written
    // alongside each invoice save instead of counting on read.
    await Promise.all(
      users.map(async (u) => {
        try {
          const snap = await getCountFromServer(collection(db, "users", u.uid, "invoices"));
          u.invoiceCount = snap.data().count;
        } catch {
          u.invoiceCount = "—";
        }
      })
    );

    allUsers = users;
    renderUsersTable(users);
  } catch (e) {
    console.error("loadUsers failed", e);
    tbody.innerHTML = `<tr><td colspan="5" class="error-text">Failed to load users — check firestore.rules is deployed and this account is on the admin allowlist.</td></tr>`;
  }
}

function filterUsers(term) {
  const t = term.trim().toLowerCase();
  if (!t) return allUsers;
  return allUsers.filter(
    (u) => u.name.toLowerCase().includes(t) || u.email.toLowerCase().includes(t)
  );
}

function renderUsersTable(users) {
  const tbody = document.getElementById("users-tbody");
  if (users.length === 0) {
    tbody.innerHTML = `<tr><td colspan="5" class="muted">No users found.</td></tr>`;
    return;
  }

  tbody.innerHTML = users
    .map(
      (u) => `
    <tr>
      <td>${escapeHtml(u.name)}</td>
      <td>${escapeHtml(u.email)}</td>
      <td>${u.invoiceCount ?? "—"}</td>
      <td><span class="badge ${u.isPremium ? "badge-premium" : "badge-free"}">${
        u.isPremium ? "Premium" : "Free"
      }</span></td>
      <td><button class="btn-toggle" data-uid="${u.uid}" data-premium="${u.isPremium}">
        ${u.isPremium ? "Revoke" : "Grant"} premium
      </button></td>
    </tr>`
    )
    .join("");

  tbody.querySelectorAll(".btn-toggle").forEach((btn) => {
    btn.addEventListener("click", () => togglePremium(btn));
  });
}

async function togglePremium(btn) {
  const uid = btn.dataset.uid;
  const makePremium = btn.dataset.premium !== "true";
  btn.disabled = true;
  btn.textContent = "Saving…";
  try {
    await setDoc(
      doc(db, "subscriptions", uid),
      { isPremium: makePremium, grantedByAdmin: auth.currentUser.email },
      { merge: true }
    );
    await loadUsers();
    await loadCounts();
  } catch (e) {
    console.error("togglePremium failed", e);
    alert("Could not update this account's plan. See console for details.");
    btn.disabled = false;
    btn.textContent = makePremium ? "Grant premium" : "Revoke premium";
  }
}

async function loadRecentInvoices() {
  const tbody = document.getElementById("invoices-tbody");
  tbody.innerHTML = `<tr><td colspan="6" class="muted">Loading…</td></tr>`;

  try {
    const q = query(
      collectionGroup(db, "invoices"),
      orderBy("createdAt", "desc"),
      limit(RECENT_INVOICES_LIMIT)
    );
    const snap = await getDocs(q);

    if (snap.empty) {
      tbody.innerHTML = `<tr><td colspan="6" class="muted">No invoices yet.</td></tr>`;
      return;
    }

    tbody.innerHTML = snap.docs
      .map((d) => {
        const data = d.data();
        const ownerUid = d.ref.parent.parent?.id || "—";
        const status = (data.status || "draft").toLowerCase();
        const created = data.createdAt?.toDate
          ? data.createdAt.toDate().toLocaleDateString()
          : "—";
        return `
        <tr>
          <td>${escapeHtml(data.invoiceNumber || d.id)}</td>
          <td>${escapeHtml(data.clientName || "—")}</td>
          <td><code>${escapeHtml(ownerUid)}</code></td>
          <td>${formatCurrency(data.grandTotal || 0)}</td>
          <td><span class="badge badge-${status}">${escapeHtml(status)}</span></td>
          <td>${created}</td>
        </tr>`;
      })
      .join("");
  } catch (e) {
    console.error("loadRecentInvoices failed", e);
    tbody.innerHTML = `<tr><td colspan="6" class="error-text">Failed to load invoices — this query needs a Firestore index for collectionGroup('invoices') ordered by createdAt; Firestore will log a direct link to create it the first time this runs against your project.</td></tr>`;
  }
}

// ── Helpers ──────────────────────────────────────────────────────────────

function setStat(id, value) {
  document.getElementById(id).textContent = value;
}

function formatCurrency(n) {
  return "₹" + Number(n).toLocaleString("en-IN", { maximumFractionDigits: 0 });
}

function escapeHtml(str) {
  return String(str)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}
