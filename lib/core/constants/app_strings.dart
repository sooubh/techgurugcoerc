/// App-wide string constants for CARE-AI.
class AppStrings {
  AppStrings._();

  static const String appName = 'CARE-AI';
  static const String tagline = 'Helping Parents. Helping Every Child.';
  static const String taglineShort = 'Simple Help for Daily Parenting';

  // ─── Auth ────────────────────────────────────────────────────
  static const String login = 'Log In';
  static const String signUp = 'Sign Up';
  static const String email = 'Email';
  static const String password = 'Password';
  static const String confirmPassword = 'Confirm Password';
  static const String forgotPassword = 'Forgot Password?';
  static const String resetPassword = 'Reset Password';
  static const String noAccount = "Don't have an account? ";
  static const String hasAccount = 'Already have an account? ';
  static const String loginSuccess = 'Welcome back! 👋';
  static const String signUpSuccess =
      'Account created! Let\'s set up your child\'s profile.';
  static const String continueWithGoogle = 'Continue with Google';
  static const String continueWithPhone = 'Continue with Phone';
  static const String orDivider = 'or continue with';
  static const String fullName = 'Full Name';
  static const String phoneNumber = 'Phone Number';

  // ─── Onboarding ──────────────────────────────────────────────
    static const String onboardingTitle1 = 'Expert Help';
  static const String onboardingDesc1 =
      'Use simple therapy activities made by experts for your child.';
    static const String onboardingTitle2 = 'AI Help';
  static const String onboardingDesc2 =
      'Get quick parenting help from AI anytime you need it.';
    static const String onboardingTitle3 = 'See Progress';
  static const String onboardingDesc3 =
      'See your child\'s growth and connect with doctors easily.';
  static const String getStarted = 'Get Started';
  static const String skip = 'Skip';
  static const String next = 'Next';

  // ─── Profile ─────────────────────────────────────────────────
  static const String profileSetup = 'Child Profile';
  static const String childName = "Child's Name";
  static const String childAge = "Child's Age";
  static const String childGender = 'Gender (Optional)';
  static const String condition = 'Conditions';
  static const String communicationLevel = 'Communication Level';
  static const String behavioralConcerns = 'Behavioral Concerns';
  static const String sensoryIssues = 'Sensory Sensitivities';
  static const String motorSkills = 'Motor Skill Level';
  static const String learningAbilities = 'Learning Abilities';
  static const String parentGoals = 'Your Goals';
  static const String currentTherapy = 'Current Therapy Status';
  static const String saveProfile = 'Save Profile';
  static const String editProfile = 'Edit Profile';

  // ─── Dashboard ───────────────────────────────────────────────
  static const String dashboard = 'Dashboard';
  static const String todaysPlan = "Today's Plan";
  static const String quickActions = 'Quick Actions';
  static const String recentProgress = 'Recent Updates';
  static const String recommendations = 'Suggested for You';

  // ─── Navigation ──────────────────────────────────────────────
  static const String home = 'Home';
  static const String askAi = 'Talk to AI';
  static const String activities = 'Activities';
  static const String progress = 'Progress';
  static const String profile = 'Profile';
  static const String settings = 'Settings';
  static const String games = 'Games';
  static const String dailyPlan = 'Daily Plan';

  // ─── Chat ────────────────────────────────────────────────────
  static const String chatTitle = 'AI Assistant';
  static const String typeMessage = 'Type your message...';
  static const String chatWelcome =
      'Hi! I am your CARE-AI helper.\nHow can I help today?';

  // ─── Emergency ───────────────────────────────────────────────
  static const String emergency = 'Emergency Support';
  static const String meltdownMode = 'Meltdown Support';
  static const String calmingSteps = 'Follow these calming steps:';

  // ─── Disclaimer ──────────────────────────────────────────────
  static const String disclaimer =
      'CARE-AI does not give medical diagnosis. '
      'Please talk to a doctor for medical advice.';
  static const String disclaimerShort =
      'Not a replacement for doctor advice.';

  // ─── Communication Levels ────────────────────────────────────
  static const List<String> communicationLevels = [
    'Non-verbal',
    'Limited words',
    'Phrases',
    'Full sentences',
    'Right for age',
  ];

  // ─── Common Conditions ───────────────────────────────────────
  static const List<String> commonConditions = [
    'Autism Spectrum Disorder (ASD)',
    'ADHD',
    'Speech Delay',
    'Cerebral Palsy',
    'Down Syndrome',
    'Learning Disability',
    'Sensory Processing Disorder',
    'Other',
  ];

  // ─── Motor Skill Levels ──────────────────────────────────────
  static const List<String> motorSkillLevels = [
    'Needs a lot of help',
    'Needs some help',
    'Needs a little help',
    'Right for age',
  ];

  // ─── Behavioral Concerns ─────────────────────────────────────
  static const List<String> commonBehavioralConcerns = [
    'Frequent meltdowns',
    'Self-stimulation (stimming)',
    'Difficulty with transitions',
    'Aggression',
    'Stays alone often',
    'Sleep problems',
    'Eating problems',
    'Hyperactivity',
    'Anxiety',
    'Other',
  ];

  // ─── Sensory Issues ──────────────────────────────────────────
  static const List<String> commonSensoryIssues = [
    'Sound sensitivity',
    'Light sensitivity',
    'Does not like touch',
    'Taste / texture sensitivity',
    'Seeking sensory input',
    'Balance problems',
    'Body awareness problems',
    'None',
  ];

  // ─── Parent Goals ────────────────────────────────────────────
  static const List<String> commonParentGoals = [
    'Improve communication',
    'Reduce behavior problems',
    'Develop social skills',
    'Improve motor skills',
    'Help with school learning',
    'Build daily routines',
    'Improve sensory calm',
    'Do more things alone',
    'Other',
  ];

  // ─── Therapy Statuses ────────────────────────────────────────
  static const List<String> therapyStatuses = [
    'Not in therapy now',
    'Speech therapy',
    'Occupational therapy',
    'ABA therapy',
    'Physical therapy',
    'Multiple therapies',
    'Other',
  ];

  // ─── Genders ─────────────────────────────────────────────────
  static const List<String> genders = [
    'Male',
    'Female',
    'Non-binary',
    'Prefer not to say',
  ];
}
