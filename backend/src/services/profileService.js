async function getProfileService(userId) {
  return {
    id: userId,
    displayName: 'VisionAid User',
    email: 'user@visionaid.app',
    preferences: {
      voiceEnabled: true,
      darkMode: true,
      offlineMode: true,
    },
  };
}

async function updateProfileService(userId, updates) {
  return {
    id: userId,
    ...updates,
    updatedAt: new Date().toISOString(),
  };
}

module.exports = {
  getProfileService,
  updateProfileService,
};
