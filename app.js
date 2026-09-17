const state = {
  kind: null,
  phase: "idle",
  cigaretteCount: Number(localStorage.getItem("smok-count") || 20),
  podLevel: Number(localStorage.getItem("smok-pod") || 100),
  remaining: 100,
  sound: false,
};

const $ = (selector) => document.querySelector(selector);
const selector = $("#selector");
const scene = $("#objectScene");
const product = $("#stageProduct");
const cigarette = $("#cigarette");
const progress = $("#progressBar");
const actionTitle = $("#actionTitle");
const actionHint = $("#actionHint");

function vibrate(pattern = 18) {
  if (navigator.vibrate) navigator.vibrate(pattern);
}

function updateInventory() {
  $("#packCount").textContent = `${state.cigaretteCount}개비`;
  $("#podCount").textContent = `${state.podLevel}%`;
  $("#stageCount").textContent = state.kind === "cigarette" ? `${state.cigaretteCount}개비 남음` : `배터리 ${state.podLevel}%`;
}

function showToast(message) {
  const toast = $("#toast");
  toast.textContent = message;
  toast.classList.add("show");
  clearTimeout(showToast.timer);
  showToast.timer = setTimeout(() => toast.classList.remove("show"), 1500);
}

function choose(kind) {
  state.kind = kind;
  state.phase = "ready";
  state.remaining = 100;
  document.body.classList.add("in-session");
  scene.className = "object-scene";
  cigarette.className = "cigarette";
  cigarette.style.setProperty("--burn", "0px");
  $("#vapeGlow").style.display = "none";
  product.src = kind === "cigarette" ? "assets/cigarette-pack.png" : "assets/vape.png";
  product.alt = kind === "cigarette" ? "열린 담뱃갑" : "전자담배";
  product.className = `stage-product ${kind === "vape" ? "vape-mode" : ""}`;
  $("#stageLabel").textContent = kind === "cigarette" ? "CLASSIC" : "POD";
  actionTitle.textContent = kind === "cigarette" ? "꺼내려면 탭하세요" : "시작하려면 탭하세요";
  actionHint.textContent = "화면 어디든 가볍게";
  setProgress(100);
  updateInventory();
  vibrate();
}

function setProgress(value) {
  state.remaining = Math.max(0, value);
  progress.style.width = `${state.remaining}%`;
  $("#progressText").textContent = `${state.remaining}%`;
}

function makeSmoke(amount = 3) {
  const cloud = $("#smokeCloud");
  for (let i = 0; i < amount; i++) {
    const puff = document.createElement("i");
    puff.className = "puff";
    puff.style.setProperty("--drift", `${Math.round(Math.random() * 100 - 50)}px`);
    puff.style.left = `${46 + Math.random() * 8}%`;
    puff.style.animationDelay = `${i * 120}ms`;
    cloud.appendChild(puff);
    setTimeout(() => puff.remove(), 3300);
  }
}

function advance() {
  if (!state.kind) return;
  vibrate(state.phase === "smoking" ? 10 : 28);

  if (state.phase === "ready") {
    state.phase = "drawn";
    if (state.kind === "cigarette") {
      cigarette.classList.add("visible");
      requestAnimationFrame(() => scene.classList.add("extracted"));
      actionTitle.textContent = "불을 붙이려면 탭하세요";
    } else {
      scene.classList.add("extracted");
      actionTitle.textContent = "천천히 들이마셔요";
    }
    actionHint.textContent = "다음 탭에서 시작돼요";
    return;
  }

  if (state.phase === "drawn") {
    state.phase = "smoking";
    cigarette.classList.toggle("lit", state.kind === "cigarette");
    scene.classList.toggle("vaping", state.kind === "vape");
    $("#vapeGlow").style.display = state.kind === "vape" ? "block" : "none";
    actionTitle.textContent = "화면을 탭해 피워보세요";
    actionHint.textContent = "탭할 때마다 조금씩 줄어들어요";
    makeSmoke(2);
    return;
  }

  if (state.phase === "finished") return finishAndReturn();

  const burn = state.kind === "cigarette" ? 9 : 7;
  setProgress(state.remaining - burn);
  if (state.kind === "cigarette") cigarette.style.setProperty("--burn", `${(100 - state.remaining) * 1.45}px`);
  makeSmoke(Math.random() > .55 ? 4 : 3);

  if (state.remaining <= 0) {
    state.phase = "finished";
    if (state.kind === "cigarette") {
      state.cigaretteCount = Math.max(0, state.cigaretteCount - 1);
      localStorage.setItem("smok-count", state.cigaretteCount);
    } else {
      state.podLevel = Math.max(0, state.podLevel - 5);
      localStorage.setItem("smok-pod", state.podLevel);
    }
    cigarette.classList.remove("lit");
    scene.classList.remove("vaping");
    actionTitle.textContent = "휴식 끝";
    actionHint.textContent = "탭해서 돌아가기";
    updateInventory();
    showToast("한 번의 느린 숨을 마쳤어요");
    vibrate([30, 60, 30]);
  }
}

function finishAndReturn() {
  document.body.classList.remove("in-session");
  state.kind = null;
  state.phase = "idle";
}

selector.addEventListener("click", (event) => {
  const card = event.target.closest(".product-card");
  if (card) choose(card.dataset.kind);
});
$("#ritualButton").addEventListener("click", advance);
$("#objectScene").addEventListener("click", advance);
$("#backButton").addEventListener("click", finishAndReturn);
$("#resetButton").addEventListener("click", () => {
  state.cigaretteCount = 20; state.podLevel = 100;
  localStorage.removeItem("smok-count"); localStorage.removeItem("smok-pod");
  updateInventory(); showToast("새 제품으로 채웠어요"); vibrate();
});
$("#soundButton").addEventListener("click", () => {
  state.sound = !state.sound;
  showToast(state.sound ? "사운드가 켜졌어요" : "사운드가 꺼졌어요");
});

updateInventory();
if ("serviceWorker" in navigator && location.protocol !== "file:") navigator.serviceWorker.register("sw.js");
