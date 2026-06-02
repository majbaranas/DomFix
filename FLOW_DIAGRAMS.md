# 🎨 Visual Flow Diagrams - Role-Based Authentication

## 📱 Complete App Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                         APP LAUNCH                               │
│                              ↓                                   │
│                      SPLASH SCREEN                               │
│                              ↓                                   │
│                    Check Auth Status                             │
│                              ↓                                   │
│         ┌────────────────────┴────────────────────┐             │
│         ↓                                          ↓             │
│   NOT LOGGED IN                              LOGGED IN           │
│         ↓                                          ↓             │
│    ┌────┴────┐                              Check Role          │
│    ↓         ↓                                     ↓             │
│  First    Return                    ┌─────────────┼─────────┐   │
│  Launch   User                      ↓             ↓         ↓   │
│    ↓         ↓                   No Role      Client    Technician│
│ Onboard   Login                     ↓             ↓         ↓   │
│  Screen   Screen                  Role        Client    Check    │
│    ↓         ↓                  Selection     Home    Onboarding │
│    └────┬────┘                   Screen      Screen      ↓      │
│         ↓                            ↓          ↑    ┌────┴────┐ │
│    LOGIN SCREEN ←────────────────────┘          │    ↓         ↓ │
│         ↓                                       │  Not Done  Done│
│    Authenticate                                 │    ↓         ↓ │
│         ↓                                       │ Onboard  Technician│
│  NavigationService                              │  Flow     Home   │
│  .navigateBasedOnRole()                         │    ↓      Screen │
│         ↓                                       │    └────────┘   │
│    [Routes to appropriate screen]               └─────────────────┘
└─────────────────────────────────────────────────────────────────┘
```

## 🔐 Authentication Flow

```
┌──────────────────────────────────────────────────────────────┐
│                    AUTHENTICATION FLOW                        │
├──────────────────────────────────────────────────────────────┤
│                                                               │
│  New User                        Existing User               │
│     ↓                                  ↓                      │
│  Register                           Login                     │
│     ↓                                  ↓                      │
│  Email/Password                   Email/Password              │
│  or Google                        or Google                   │
│     ↓                                  ↓                      │
│  Set isLoggedIn = true            Set isLoggedIn = true       │
│     ↓                                  ↓                      │
│  Check Role                       Check Role                  │
│     ↓                                  ↓                      │
│  ┌──┴──┐                          ┌───┴───┐                  │
│  ↓     ↓                          ↓       ↓                   │
│ Null  Exists                    Null   Exists                 │
│  ↓     ↓                          ↓       ↓                   │
│ Role  Skip                       Role    Go to                │
│ Select Role                     Select  Home                  │
│  ↓    Select                      ↓      ↓                    │
│  └──┬──┘                          └──────┘                    │
│     ↓                                                          │
│  Save Role                                                     │
│     ↓                                                          │
│  Navigate                                                      │
│                                                               │
└──────────────────────────────────────────────────────────────┘
```

## 👥 Role Selection Flow

```
┌──────────────────────────────────────────────────────────────┐
│                   ROLE SELECTION SCREEN                       │
├──────────────────────────────────────────────────────────────┤
│                                                               │
│              ┌─────────────────────────┐                      │
│              │  Choose Your Role       │                      │
│              └─────────────────────────┘                      │
│                         ↓                                     │
│         ┌───────────────┴───────────────┐                     │
│         ↓                               ↓                     │
│   ┌──────────┐                    ┌──────────┐               │
│   │  CLIENT  │                    │TECHNICIAN│               │
│   │          │                    │          │               │
│   │ I need   │                    │   I'm a  │               │
│   │  help    │                    │   pro    │               │
│   └──────────┘                    └──────────┘               │
│         ↓                               ↓                     │
│    Save role                       Save role                  │
│   "client"                        "technician"                │
│         ↓                               ↓                     │
│    Navigate to                    Navigate to                │
│  ClientHomeScreen              TechnicianOnboarding           │
│         ↓                               ↓                     │
│    ┌─────────┐                   Complete Steps              │
│    │  HOME   │                          ↓                     │
│    │ • Home  │                   Set onboarding_completed     │
│    │ • AI    │                          ↓                     │
│    │ • Pros  │                   Navigate to                  │
│    │ • Control│               TechnicianHomeScreen            │
│    │ • Settings│                        ↓                     │
│    └─────────┘                   ┌─────────┐                 │
│                                  │  HOME   │                 │
│                                  │ • Dashboard│              │
│                                  │ • Jobs  │                 │
│                                  │ • Profile│                │
│                                  │ • Settings│               │
│                                  └─────────┘                 │
│                                                               │
└──────────────────────────────────────────────────────────────┘
```

## 🔄 Navigation Service Logic

```
┌──────────────────────────────────────────────────────────────┐
│         NavigationService.navigateBasedOnRole()               │
├──────────────────────────────────────────────────────────────┤
│                                                               │
│                    Get User Role                              │
│                         ↓                                     │
│              ┌──────────┼──────────┐                          │
│              ↓          ↓          ↓                          │
│           NULL      "client"  "technician"                    │
│              ↓          ↓          ↓                          │
│           Role      Client    Check Onboarding               │
│         Selection    Home          ↓                          │
│          Screen    Screen    ┌─────┴─────┐                   │
│                               ↓           ↓                   │
│                          Not Done      Done                   │
│                               ↓           ↓                   │
│                          Onboarding  Technician               │
│                            Flow        Home                   │
│                               ↓        Screen                 │
│                          Complete                             │
│                               ↓                               │
│                          Set Done                             │
│                               ↓                               │
│                          Technician                           │
│                            Home                               │
│                           Screen                              │
│                                                               │
└──────────────────────────────────────────────────────────────┘
```

## 🚪 Logout Flow

```
┌──────────────────────────────────────────────────────────────┐
│                        LOGOUT FLOW                            │
├──────────────────────────────────────────────────────────────┤
│                                                               │
│                    User in Home Screen                        │
│                            ↓                                  │
│                    Navigate to Settings                       │
│                            ↓                                  │
│                    Click "Logout" Button                      │
│                            ↓                                  │
│                    Show Confirmation Dialog                   │
│                            ↓                                  │
│                    ┌───────┴───────┐                          │
│                    ↓               ↓                          │
│                 Cancel          Confirm                       │
│                    ↓               ↓                          │
│                 Stay In      AuthService.signOut()            │
│                 Settings           ↓                          │
│                              PreferencesService.logout()      │
│                                    ↓                          │
│                              Clear all data:                  │
│                              • isLoggedIn = false             │
│                              • user_role = null               │
│                              • onboarding_completed = false   │
│                                    ↓                          │
│                              NavigationService.logout()       │
│                                    ↓                          │
│                              Navigate to LoginScreen          │
│                              (Clear back stack)               │
│                                    ↓                          │
│                              User must login again            │
│                                                               │
└──────────────────────────────────────────────────────────────┘
```

## 💾 Data Flow

```
┌──────────────────────────────────────────────────────────────┐
│                    DATA PERSISTENCE FLOW                      │
├──────────────────────────────────────────────────────────────┤
│                                                               │
│  User Action              SharedPreferences         Screen    │
│      ↓                           ↓                    ↓       │
│  ┌────────┐              ┌──────────────┐      ┌─────────┐   │
│  │Register│ ────────────→│isLoggedIn    │      │ Role    │   │
│  └────────┘              │= true        │      │Selection│   │
│      ↓                   └──────────────┘      └─────────┘   │
│  ┌────────┐                     ↓                    ↓       │
│  │ Select │              ┌──────────────┐      ┌─────────┐   │
│  │  Role  │ ────────────→│user_role     │      │  Home   │   │
│  └────────┘              │= "client" or │      │ Screen  │   │
│                          │  "technician"│      └─────────┘   │
│                          └──────────────┘            ↓       │
│                                 ↓                            │
│  ┌────────┐              ┌──────────────┐      ┌─────────┐   │
│  │Complete│ ────────────→│onboarding_   │      │Technician│  │
│  │Onboard │              │completed     │      │  Home   │   │
│  └────────┘              │= true        │      └─────────┘   │
│                          └──────────────┘                    │
│      ↓                          ↓                            │
│  ┌────────┐              ┌──────────────┐                    │
│  │ Logout │ ────────────→│Clear all data│                    │
│  └────────┘              └──────────────┘                    │
│                                 ↓                            │
│                          Back to Login                        │
│                                                               │
└──────────────────────────────────────────────────────────────┘
```

## 🎯 Screen Hierarchy

```
┌──────────────────────────────────────────────────────────────┐
│                     SCREEN HIERARCHY                          │
├──────────────────────────────────────────────────────────────┤
│                                                               │
│                        SplashScreen                           │
│                             ↓                                 │
│              ┌──────────────┼──────────────┐                  │
│              ↓              ↓              ↓                  │
│        OnboardingScreen LoginScreen  RoleSelectionScreen      │
│              ↓              ↓              ↓                  │
│              └──────────────┼──────────────┘                  │
│                             ↓                                 │
│                      LoginScreen                              │
│                             ↓                                 │
│              ┌──────────────┼──────────────┐                  │
│              ↓                             ↓                  │
│      ClientHomeScreen            TechnicianHomeScreen         │
│              ↓                             ↓                  │
│      ┌───────┴───────┐            ┌────────┴────────┐         │
│      ↓       ↓       ↓            ↓        ↓        ↓         │
│    Home   AI Chat  Pros      Dashboard  Jobs   Profile        │
│      ↓       ↓       ↓            ↓        ↓        ↓         │
│   Control Settings  ...        Settings   ...      ...        │
│                                                               │
└──────────────────────────────────────────────────────────────┘
```

## 🔑 Key Decision Points

```
┌──────────────────────────────────────────────────────────────┐
│                   DECISION TREE                               │
├──────────────────────────────────────────────────────────────┤
│                                                               │
│  Q: Is user logged in?                                        │
│  ├─ NO  → Show Login/Onboarding                               │
│  └─ YES → Continue                                            │
│                                                               │
│  Q: Does user have a role?                                    │
│  ├─ NO  → Show Role Selection                                 │
│  └─ YES → Continue                                            │
│                                                               │
│  Q: What is the role?                                         │
│  ├─ CLIENT     → Go to ClientHomeScreen                       │
│  └─ TECHNICIAN → Continue                                     │
│                                                               │
│  Q: Is onboarding complete?                                   │
│  ├─ NO  → Show Onboarding Flow                                │
│  └─ YES → Go to TechnicianHomeScreen                          │
│                                                               │
└──────────────────────────────────────────────────────────────┘
```

## 📊 State Management

```
┌──────────────────────────────────────────────────────────────┐
│                    STATE MANAGEMENT                           │
├──────────────────────────────────────────────────────────────┤
│                                                               │
│  SharedPreferences (Persistent)                               │
│  ┌────────────────────────────────────────────────┐           │
│  │ • isFirstLaunch: bool                          │           │
│  │ • isLoggedIn: bool                             │           │
│  │ • user_role: String ("client"/"technician")    │           │
│  │ • onboarding_completed: bool                   │           │
│  └────────────────────────────────────────────────┘           │
│                        ↓                                      │
│  PreferencesService (Helper Methods)                          │
│  ┌────────────────────────────────────────────────┐           │
│  │ • getUserRole()                                │           │
│  │ • setUserRole(String)                          │           │
│  │ • isLoggedIn()                                 │           │
│  │ • setLoggedIn(bool)                            │           │
│  │ • isOnboardingCompleted()                      │           │
│  │ • setOnboardingCompleted(bool)                 │           │
│  │ • logout()                                     │           │
│  └────────────────────────────────────────────────┘           │
│                        ↓                                      │
│  NavigationService (Navigation Logic)                         │
│  ┌────────────────────────────────────────────────┐           │
│  │ • navigateBasedOnRole(context)                 │           │
│  │ • logout(context)                              │           │
│  └────────────────────────────────────────────────┘           │
│                                                               │
└──────────────────────────────────────────────────────────────┘
```

---

**Legend:**
- `→` : Navigation/Flow
- `↓` : Sequential step
- `┌─┴─┐` : Decision point
- `[ ]` : Process/Action
- `( )` : State/Data

---

**These diagrams illustrate the complete flow of the role-based authentication system.**
