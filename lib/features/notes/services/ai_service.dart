class AiService {
  /// Analyzes a safety note locally using zero-cost keyword heuristics
  /// and returns exactly two actionable safety instructions.
  static List<String> analyzeSafetyNote(String note) {
    final cleanNote = note.toLowerCase();

    // Riot / Protests
    if (cleanNote.contains("riot") ||
        cleanNote.contains("protest") ||
        cleanNote.contains("strike") ||
        cleanNote.contains("fight") ||
        cleanNote.contains("crowd")) {
      return [
        "Change your route immediately to bypass the gathering area.",
        "Do not stop to record video; find a safe indoor shelter if routes are blocked."
      ];
    }

    // Checkpoints / Police
    if (cleanNote.contains("checkpoint") ||
        cleanNote.contains("police") ||
        cleanNote.contains("officer") ||
        cleanNote.contains("soldier") ||
        cleanNote.contains("army")) {
      return [
        "Remain calm, keep your hands visible, and turn on the inner cabin light if it is night.",
        "Have your identification documents ready and comply with official instructions."
      ];
    }

    // Dark / Night
    if (cleanNote.contains("dark") ||
        cleanNote.contains("night") ||
        cleanNote.contains("light") ||
        cleanNote.contains("evening")) {
      return [
        "Avoid using your phone or wearing headphones to stay fully aware of your surroundings.",
        "Stick to well-lit main roads and walk briskly towards public or commercial zones."
      ];
    }

    // Traffic / Jams
    if (cleanNote.contains("traffic") ||
        cleanNote.contains("jam") ||
        cleanNote.contains("gridlock") ||
        cleanNote.contains("delay")) {
      return [
        "Keep your vehicle windows rolled up and doors locked securely.",
        "Avoid displaying valuable items (phones, laptops) near windows."
      ];
    }

    // Suspicious Activity / Being Followed
    if (cleanNote.contains("suspicious") ||
        cleanNote.contains("follow") ||
        cleanNote.contains("stranger") ||
        cleanNote.contains("stalk")) {
      return [
        "Cross the street or change directions immediately to test if you are being followed.",
        "Head directly towards the nearest populated shop, security post, or police station."
      ];
    }

    // Ridesharing / Taxis
    if (cleanNote.contains("cab") ||
        cleanNote.contains("taxi") ||
        cleanNote.contains("uber") ||
        cleanNote.contains("bolt") ||
        cleanNote.contains("ride") ||
        cleanNote.contains("bus")) {
      return [
        "Verify that the driver's profile and vehicle plate match the ride details exactly.",
        "Share your live tracking link with your emergency contacts immediately."
      ];
    }

    // Default general advice
    return [
      "Keep your phone accessible but hidden from view.",
      "Stay alert, watch your surroundings, and have the panic button ready."
    ];
  }
}
