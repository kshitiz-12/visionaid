/**
 * Sensitive actions (pay / send / place order) wait here until the user
 * says "confirm" or "cancel" from the voice app.
 */
class ConfirmGate {
  constructor() {
    this.pending = null;
  }

  propose(action) {
    this.pending = {
      id: `p_${Date.now()}`,
      createdAt: new Date().toISOString(),
      ...action,
    };
    return this.pending;
  }

  get() {
    return this.pending;
  }

  clear() {
    const was = this.pending;
    this.pending = null;
    return was;
  }
}

export const confirmGate = new ConfirmGate();
