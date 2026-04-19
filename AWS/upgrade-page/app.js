const DEFAULT_API_BASE = "https://f4apx2tkemgn5i2vagzhboeyjm0nnnjh.lambda-url.eu-north-1.on.aws";
const API_BASE = (window.NATIVEFORMS_API_BASE || DEFAULT_API_BASE).replace(/\/+$/, "");
const COMMON_FEATURES = [
  {
    key: "native-builder",
    label: "Native Salesforce Form Builder",
    description: "A truly native TwinaForms experience built to work directly with Salesforce."
  },
  {
    key: "native-prefill",
    label: "Native Prefill",
    description: "Bring Salesforce data into forms with built-in native prefill behavior."
  },
  {
    key: "native-submit",
    label: "Native Submit",
    description: "Send form results back into Salesforce with native submit actions."
  },
  {
    key: "any-object",
    label: "Any Standard Or Custom Object",
    description: "Build against the Salesforce objects your org already uses, including custom objects."
  },
  {
    key: "anyone-can-use",
    label: "Anyone Can Use It",
    description: "Published forms are designed for external users, not just Salesforce license holders."
  }
];
const MARKETING_DESCRIPTIONS = {
  starter: "Ready to go live with production forms, clear limits, and an easy path to scale."
};

const statusMessage = document.getElementById("statusMessage");
const plansGrid = document.getElementById("plansGrid");
const planCardTemplate = document.getElementById("planCardTemplate");

function setStatus(message, isError = false) {
  statusMessage.textContent = message;
  statusMessage.hidden = false;
  statusMessage.classList.toggle("status-message--error", isError);
}

function formatPill(plan) {
  if (plan.planCode === "trial" && Number.isFinite(plan.durationDays) && plan.durationDays > 0) {
    return `${plan.durationDays}-day trial`;
  }

  return plan.planCode === "pro" ? "Full access" : "Live plan";
}

function renderLimitItem(limit) {
  const item = document.createElement("div");
  item.className = "limit-item";
  item.innerHTML = `
    <span class="limit-item__label">${limit.label}</span>
    <span class="limit-item__value">${limit.value}</span>
  `;
  return item;
}

function renderFeatureItem(feature) {
  const item = document.createElement("li");
  item.className = "feature-item";
  item.innerHTML = `
    <span class="feature-item__label">${feature.label}</span>
    <p class="feature-item__description">${feature.description || ""}</p>
  `;
  return item;
}

function getPlanDescription(plan) {
  return MARKETING_DESCRIPTIONS[plan.planCode] || plan.description || "";
}

function getPlanFeatures(plan) {
  return [...COMMON_FEATURES, ...(plan.features || [])];
}

function renderPlans(plans) {
  plansGrid.innerHTML = "";

  plans.forEach((plan) => {
    const fragment = planCardTemplate.content.cloneNode(true);
    const card = fragment.querySelector(".plan-card");
    const eyebrow = fragment.querySelector(".plan-card__eyebrow");
    const title = fragment.querySelector(".plan-card__title");
    const pill = fragment.querySelector(".plan-card__pill");
    const description = fragment.querySelector(".plan-card__description");
    const limitsContainer = fragment.querySelector(".plan-card__limits");
    const featuresContainer = fragment.querySelector(".plan-card__features");

    eyebrow.textContent = plan.planCode;
    title.textContent = plan.label;
    pill.textContent = formatPill(plan);
    description.textContent = getPlanDescription(plan);

    if (plan.planCode === "starter" || plan.planCode === "pro") {
      card.classList.add("plan-card--highlight");
    }

    (plan.limitSummary || []).forEach((limit) => {
      limitsContainer.appendChild(renderLimitItem(limit));
    });

    getPlanFeatures(plan).forEach((feature) => {
      featuresContainer.appendChild(renderFeatureItem(feature));
    });

    plansGrid.appendChild(fragment);
  });

  statusMessage.hidden = true;
  plansGrid.hidden = false;
}

async function loadPlans() {
  setStatus("Loading plans...");

  try {
    const response = await fetch(`${API_BASE}/public/plans`);
    const payload = await response.json();

    if (!response.ok || payload.success !== true || !Array.isArray(payload.items)) {
      throw new Error(payload?.error || "Unable to load TwinaForms plans.");
    }

    renderPlans(payload.items);
  } catch (error) {
    console.error("Failed to load plans:", error);
    plansGrid.hidden = true;
    setStatus("We could not load the latest plans right now. Please try again shortly.", true);
  }
}

loadPlans();
