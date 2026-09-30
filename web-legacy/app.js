"use strict";

/* ============================================================
   Stash — gestion de cartes de fidélité en local (PWA)
   Aucune donnée n'est envoyée sur un serveur : tout est
   stocké dans le localStorage du navigateur.
   ============================================================ */

(function () {
  const STORAGE_KEY = "stash.cards.v1";

  const PALETTE = [
    "#4c8dff", "#ff5a5f", "#34c759", "#ff9f0a",
    "#af52de", "#00c7be", "#ff375f", "#5e5ce6",
    "#8e8e93", "#1c1c1e"
  ];

  /** @typedef {{id:string,name:string,code:string,format:string,color:string}} Card */

  // --- Références DOM ---
  const cardList = document.getElementById("cardList");
  const emptyState = document.getElementById("emptyState");
  const addBtn = document.getElementById("addBtn");
  const emptyAddBtn = document.getElementById("emptyAddBtn");

  const formOverlay = document.getElementById("formOverlay");
  const cardForm = document.getElementById("cardForm");
  const formTitle = document.getElementById("formTitle");
  const cardIdInput = document.getElementById("cardId");
  const cardName = document.getElementById("cardName");
  const cardCode = document.getElementById("cardCode");
  const cardFormat = document.getElementById("cardFormat");
  const colorPicker = document.getElementById("colorPicker");
  const cancelBtn = document.getElementById("cancelBtn");
  const deleteBtn = document.getElementById("deleteBtn");

  const detailOverlay = document.getElementById("detailOverlay");
  const detailClose = document.getElementById("detailClose");
  const detailName = document.getElementById("detailName");
  const detailCode = document.getElementById("detailCode");
  const barcodeHolder = document.getElementById("barcodeHolder");
  const detailEdit = document.getElementById("detailEdit");

  let selectedColor = PALETTE[0];
  let currentDetailId = null;

  // --- Persistance ---
  /** @returns {Card[]} */
  function loadCards() {
    try {
      const raw = localStorage.getItem(STORAGE_KEY);
      if (!raw) return [];
      const parsed = JSON.parse(raw);
      return Array.isArray(parsed) ? parsed : [];
    } catch (err) {
      console.error("Lecture du stockage impossible :", err);
      return [];
    }
  }

  /** @param {Card[]} cards */
  function saveCards(cards) {
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(cards));
    } catch (err) {
      console.error("Écriture du stockage impossible :", err);
      alert("Impossible d'enregistrer la carte : le stockage du navigateur est plein ou bloqué.");
    }
  }

  function makeId() {
    if (window.crypto && typeof window.crypto.randomUUID === "function") {
      return window.crypto.randomUUID();
    }
    return "c_" + Date.now().toString(36) + Math.random().toString(36).slice(2, 8);
  }

  // --- Rendu de la liste ---
  function render() {
    const cards = loadCards();
    cardList.innerHTML = "";

    if (cards.length === 0) {
      emptyState.hidden = false;
      cardList.hidden = true;
      return;
    }

    emptyState.hidden = true;
    cardList.hidden = false;

    for (const card of cards) {
      const el = document.createElement("button");
      el.type = "button";
      el.className = "card";
      el.style.background = card.color || PALETTE[0];
      el.setAttribute("aria-label", "Ouvrir la carte " + card.name);
      el.dataset.id = card.id;

      const name = document.createElement("span");
      name.className = "card-name";
      name.textContent = card.name;

      const code = document.createElement("span");
      code.className = "card-code";
      code.textContent = card.code;

      el.append(name, code);
      el.addEventListener("click", () => openDetail(card.id));
      cardList.appendChild(el);
    }
  }

  // --- Sélecteur de couleur ---
  function buildColorPicker() {
    colorPicker.innerHTML = "";
    PALETTE.forEach((color) => {
      const dot = document.createElement("button");
      dot.type = "button";
      dot.className = "color-dot";
      dot.style.background = color;
      dot.setAttribute("role", "radio");
      dot.setAttribute("aria-label", "Couleur " + color);
      dot.setAttribute("aria-checked", color === selectedColor ? "true" : "false");
      dot.addEventListener("click", () => {
        selectedColor = color;
        updateColorSelection();
      });
      colorPicker.appendChild(dot);
    });
  }

  function updateColorSelection() {
    colorPicker.querySelectorAll(".color-dot").forEach((dot) => {
      dot.setAttribute("aria-checked", dot.style.background === toRgb(selectedColor) || dot.style.backgroundColor === selectedColor ? "true" : "false");
    });
    // Repli fiable : comparer via l'index de palette
    const dots = colorPicker.querySelectorAll(".color-dot");
    PALETTE.forEach((color, i) => {
      if (dots[i]) dots[i].setAttribute("aria-checked", color === selectedColor ? "true" : "false");
    });
  }

  function toRgb(hex) {
    return hex; // laissé simple : la sélection réelle se fait par index de palette
  }

  // --- Formulaire ---
  function openForm(card) {
    cardForm.reset();
    cardCode.classList.remove("invalid");
    cardName.classList.remove("invalid");

    if (card) {
      formTitle.textContent = "Modifier la carte";
      cardIdInput.value = card.id;
      cardName.value = card.name;
      cardCode.value = card.code;
      cardFormat.value = card.format || "auto";
      selectedColor = card.color || PALETTE[0];
      deleteBtn.hidden = false;
    } else {
      formTitle.textContent = "Nouvelle carte";
      cardIdInput.value = "";
      selectedColor = PALETTE[0];
      deleteBtn.hidden = true;
    }

    buildColorPicker();
    formOverlay.hidden = false;
    document.body.style.overflow = "hidden";
    setTimeout(() => cardName.focus(), 60);
  }

  function closeForm() {
    formOverlay.hidden = true;
    document.body.style.overflow = "";
  }

  function handleSubmit(event) {
    event.preventDefault();

    const name = cardName.value.trim();
    const code = cardCode.value.trim();
    let ok = true;

    if (!name) {
      cardName.classList.add("invalid");
      ok = false;
    }
    if (!code) {
      cardCode.classList.add("invalid");
      ok = false;
    }
    if (!ok) return;

    const cards = loadCards();
    const id = cardIdInput.value;

    if (id) {
      const idx = cards.findIndex((c) => c.id === id);
      if (idx !== -1) {
        cards[idx] = { ...cards[idx], name, code, format: cardFormat.value, color: selectedColor };
      }
    } else {
      cards.push({ id: makeId(), name, code, format: cardFormat.value, color: selectedColor });
    }

    saveCards(cards);
    closeForm();
    render();
  }

  function deleteCurrentCard() {
    const id = cardIdInput.value;
    if (!id) return;
    if (!confirm("Supprimer cette carte ? Cette action est définitive.")) return;

    const cards = loadCards().filter((c) => c.id !== id);
    saveCards(cards);
    closeForm();
    render();
  }

  // --- Vue plein écran + génération du code ---
  function openDetail(id) {
    const card = loadCards().find((c) => c.id === id);
    if (!card) return;

    currentDetailId = id;
    detailName.textContent = card.name;
    detailCode.textContent = card.code;
    renderBarcode(card);

    detailOverlay.hidden = false;
    document.body.style.overflow = "hidden";
    requestFullBrightnessHint();
  }

  function closeDetail() {
    detailOverlay.hidden = true;
    currentDetailId = null;
    document.body.style.overflow = "";
    barcodeHolder.innerHTML = "";
  }

  /**
   * Choisit un format quand l'utilisateur a laissé "auto" :
   * 13 chiffres -> EAN13, uniquement des chiffres/lettres courts -> CODE128,
   * sinon -> QR.
   */
  function resolveFormat(card) {
    if (card.format && card.format !== "auto") return card.format;
    const code = card.code;
    if (/^\d{13}$/.test(code)) return "EAN13";
    if (/^[0-9A-Za-z\-.$/+% ]{1,48}$/.test(code)) return "CODE128";
    return "QR";
  }

  function renderBarcode(card) {
    barcodeHolder.innerHTML = "";
    const format = resolveFormat(card);

    if (format === "QR") {
      renderQr(card.code);
      return;
    }

    // Codes-barres 1D via JsBarcode
    if (typeof window.JsBarcode !== "function") {
      showCodeFallback(card.code, "La génération du code-barres n'a pas pu se charger (hors ligne ?).");
      return;
    }

    const svg = document.createElementNS("http://www.w3.org/2000/svg", "svg");
    barcodeHolder.appendChild(svg);
    try {
      window.JsBarcode(svg, card.code, {
        format: format,
        displayValue: false,
        margin: 0,
        height: 90,
        width: 2.2
      });
    } catch (err) {
      console.error("JsBarcode a échoué :", err);
      barcodeHolder.innerHTML = "";
      showCodeFallback(card.code, "Ce numéro n'est pas valide pour un " + format + ". Modifie la carte et choisis « QR Code ».");
    }
  }

  function renderQr(text) {
    if (typeof window.qrcode !== "function") {
      showCodeFallback(text, "La génération du QR n'a pas pu se charger (hors ligne ?).");
      return;
    }
    try {
      const qr = window.qrcode(0, "M");
      qr.addData(text);
      qr.make();
      // createSvgTag(cellSize, margin)
      barcodeHolder.innerHTML = qr.createSvgTag({ cellSize: 5, margin: 0, scalable: true });
    } catch (err) {
      console.error("QR a échoué :", err);
      showCodeFallback(text, "Impossible de générer le QR pour ce contenu.");
    }
  }

  function showCodeFallback(text, message) {
    const wrap = document.createElement("div");
    const big = document.createElement("p");
    big.style.fontSize = "26px";
    big.style.fontWeight = "700";
    big.style.wordBreak = "break-all";
    big.textContent = text;
    const note = document.createElement("p");
    note.style.marginTop = "10px";
    note.style.fontSize = "13px";
    note.style.color = "#6a7080";
    note.textContent = message;
    wrap.append(big, note);
    barcodeHolder.appendChild(wrap);
  }

  /**
   * Astuce iOS : on ne peut pas forcer la luminosité par API web,
   * mais un fond blanc plein écran aide déjà le lecteur. On garde
   * ce point d'extension au cas où.
   */
  function requestFullBrightnessHint() {
    // Rien à faire côté web standard ; le fond blanc s'en charge.
  }

  // --- Câblage des événements ---
  addBtn.addEventListener("click", () => openForm(null));
  emptyAddBtn.addEventListener("click", () => openForm(null));
  cancelBtn.addEventListener("click", closeForm);
  cardForm.addEventListener("submit", handleSubmit);
  deleteBtn.addEventListener("click", deleteCurrentCard);

  detailClose.addEventListener("click", closeDetail);
  detailEdit.addEventListener("click", () => {
    const id = currentDetailId;
    closeDetail();
    const card = loadCards().find((c) => c.id === id);
    if (card) openForm(card);
  });

  // Fermer en cliquant hors de la feuille
  formOverlay.addEventListener("click", (e) => {
    if (e.target === formOverlay) closeForm();
  });

  // Touche Échap (utile en test sur ordinateur)
  document.addEventListener("keydown", (e) => {
    if (e.key !== "Escape") return;
    if (!detailOverlay.hidden) closeDetail();
    else if (!formOverlay.hidden) closeForm();
  });

  // Enregistrement du service worker (mode hors-ligne)
  if ("serviceWorker" in navigator) {
    window.addEventListener("load", () => {
      navigator.serviceWorker.register("sw.js").catch((err) => {
        console.warn("Service worker non enregistré :", err);
      });
    });
  }

  // Démarrage
  render();
})();
