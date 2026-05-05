import '../models/models.dart';

const AppUser currentUser = AppUser(
  id: '1',
  name: 'Alex Morgan',
  email: 'alex.morgan@email.com',
  projectsJoined: 5,
  tasksCompleted: 42,
);

final List<Project> projects = [
  Project(
    id: '1',
    title: 'ProjectSync App',
    description:
        'A collaboration platform combining GitHub-style project management with Discord-style communication',
    createdBy: '1',
    collaborators: {},
    visibility: 'private',
    isOpenForRequests: false,
    requiredCollaborators: 0,
    requiredSkills: [],
    contactEmail: 'contact@teamsync.com',
    lastUpdated: '2 hours ago',
    createdAt: DateTime(2025, 1, 1),
    levels: [
      ProjectLevel(
        id: '1',
        name: 'Problem Statement',
        progress: 100,
        documents: [
          ProjectDocument(
            id: '1',
            title: 'Project Overview',
            content:
                'We need a simple collaboration tool that combines project tracking with team communication...',
            attachments: [
              Attachment(
                  id: '1',
                  name: 'problem_statement.pdf',
                  type: 'pdf',
                  uploadedBy: 'Alex Morgan',
                  uploadedAt: '2 days ago'),
              Attachment(
                  id: '2',
                  name: 'architecture_diagram.png',
                  type: 'png',
                  uploadedBy: 'Sarah Chen',
                  uploadedAt: '1 day ago'),
              Attachment(
                  id: '4',
                  name: 'presentation.ppt',
                  type: 'ppt',
                  uploadedBy: 'Rahul',
                  uploadedAt: '20 hours ago'),
            ],
          ),
        ],
      ),
      ProjectLevel(
        id: '2',
        name: 'Ideation',
        progress: 80,
        documents: [
          ProjectDocument(
              id: '2',
              title: 'Feature Ideas',
              content:
                  'Core features:\n- Project management\n- Team chat\n- Document collaboration\n- Progress tracking',
              attachments: [])
        ],
      ),
      ProjectLevel(
        id: '3',
        name: 'Research',
        progress: 60,
        documents: [
          ProjectDocument(
              id: '3',
              title: 'Market Research',
              content: 'Competitive analysis of similar tools...',
              attachments: [
                Attachment(
                    id: '3',
                    name: 'competitive_analysis.ppt',
                    type: 'ppt',
                    uploadedBy: 'Mike Johnson',
                    uploadedAt: '3 days ago'),
              ])
        ],
      ),
      ProjectLevel(
          id: '4', name: 'Development', progress: 40, documents: []),
      ProjectLevel(id: '5', name: 'Testing', progress: 0, documents: []),
      ProjectLevel(
          id: '6', name: 'Documentation', progress: 20, documents: []),
    ],
    stats: ProjectStats(
        tasksCompleted: 23,
        ideasAdded: 15,
        meetingsConducted: 7,
        messagesSent: 234),
  ),
  Project(
    id: '2',
    title: 'E-Commerce Platform',
    description: 'Building a modern online store with React and Node.js',
    createdBy: '2',
    collaborators: {},
    visibility: 'public',
    isOpenForRequests: true,
    requiredCollaborators: 3,
    requiredSkills: ['React', 'Node.js'],
    contactEmail: 'commerce@example.com',
    lastUpdated: '1 day ago',
    createdAt: DateTime(2024, 12, 15),
    levels: [
      ProjectLevel(
          id: '1', name: 'Problem Statement', progress: 100, documents: []),
      ProjectLevel(
          id: '2', name: 'Ideation', progress: 100, documents: []),
      ProjectLevel(
          id: '3', name: 'Research', progress: 75, documents: []),
      ProjectLevel(
          id: '4', name: 'Development', progress: 30, documents: []),
      ProjectLevel(id: '5', name: 'Testing', progress: 0, documents: []),
      ProjectLevel(
          id: '6', name: 'Documentation', progress: 10, documents: []),
    ],
    stats: ProjectStats(
        tasksCompleted: 18,
        ideasAdded: 12,
        meetingsConducted: 5,
        messagesSent: 156),
  ),
];

final List<ChatChannel> chatChannels = [
  const ChatChannel(
    id: 'general',
    name: 'General',
    messages: [
      ChatMessage(
          id: '1',
          userId: '2',
          username: 'Rahul',
          timestamp: '10:30 AM',
          message: 'Finished the login page.'),
      ChatMessage(
          id: '2',
          userId: '3',
          username: 'Megha',
          timestamp: '10:31 AM',
          message: "I'll push the UI tonight."),
      ChatMessage(
          id: '3',
          userId: '1',
          username: 'Alex',
          timestamp: '10:35 AM',
          message: "Great work team! Let's review tomorrow."),
    ],
  ),
  const ChatChannel(
    id: 'problem-statement',
    name: 'Problem Statement',
    messages: [
      ChatMessage(
          id: '1',
          userId: '2',
          username: 'Rahul',
          timestamp: 'Yesterday',
          message: "I've uploaded the problem statement document."),
    ],
  ),
  const ChatChannel(id: 'ideation', name: 'Ideation Discussion', messages: []),
  const ChatChannel(id: 'research', name: 'Research Discussion', messages: []),
  const ChatChannel(
    id: 'development',
    name: 'Development Discussion',
    messages: [
      ChatMessage(
          id: '1',
          userId: '3',
          username: 'Megha',
          timestamp: '9:00 AM',
          message: 'Starting work on the dashboard today.'),
    ],
  ),
];

final List<AppNotification> notifications = [
  const AppNotification(
      id: '1',
      text: 'Rahul added a new idea',
      time: '10 minutes ago',
      read: false),
  const AppNotification(
      id: '2',
      text: 'Meeting scheduled tomorrow',
      time: '1 hour ago',
      read: false),
  const AppNotification(
      id: '3',
      text: 'You were added to ProjectSync',
      time: '2 hours ago',
      read: true),
  const AppNotification(
      id: '4',
      text: 'New comment on Research Discussion',
      time: 'Yesterday',
      read: true),
];

final List<Project> discoverProjects = [
  Project(
    id: '3',
    title: 'AI Study Assistant',
    description: 'An AI-powered study tool for students',
    createdBy: '3',
    collaborators: {},
    visibility: 'public',
    isOpenForRequests: true,
    requiredCollaborators: 2,
    requiredSkills: ['AI', 'Flutter'],
    contactEmail: 'ai.study@example.com',
    lastUpdated: '3 hours ago',
    createdAt: DateTime(2025, 4, 1),
    levels: [],
    stats: ProjectStats(
        tasksCompleted: 0,
        ideasAdded: 0,
        meetingsConducted: 0,
        messagesSent: 0),
  ),
  Project(
    id: '4',
    title: 'Fitness Tracker App',
    description: 'Track workouts and nutrition with ease',
    createdBy: '4',
    collaborators: {},
    visibility: 'public',
    isOpenForRequests: true,
    requiredCollaborators: 1,
    requiredSkills: ['Flutter', 'Firebase'],
    contactEmail: 'fitness@example.com',
    lastUpdated: '5 hours ago',
    createdAt: DateTime(2025, 3, 20),
    levels: [],
    stats: ProjectStats(
        tasksCompleted: 0,
        ideasAdded: 0,
        meetingsConducted: 0,
        messagesSent: 0),
  ),
  Project(
    id: '5',
    title: 'Recipe Sharing Platform',
    description: 'A community app for sharing recipes and meal plans',
    createdBy: '5',
    collaborators: {},
    visibility: 'public',
    isOpenForRequests: true,
    requiredCollaborators: 5,
    requiredSkills: ['Flutter', 'UI/UX'],
    contactEmail: 'recipes@example.com',
    lastUpdated: '1 day ago',
    createdAt: DateTime(2025, 2, 10),
    levels: [],
    stats: ProjectStats(
        tasksCompleted: 0,
        ideasAdded: 0,
        meetingsConducted: 0,
        messagesSent: 0),
  ),
];

const weeklyReportSummary =
    'This week the team completed major work on the development stage including login functionality and Firebase integration. Two meetings were conducted and several ideas were documented. The team is on track to complete the Research phase by next week.';

const List<String> weeklyReportHighlights = [
  'Completed login and authentication system',
  'Integrated Firebase backend',
  'Conducted 2 team meetings',
  'Added 5 new feature ideas',
];

final List<Meeting> meetings = [
  const Meeting(
    id: '1',
    title: 'Team Standup',
    time: '10:00 AM',
    participants: ['Alex Morgan', 'Sarah Chen', 'Rahul', 'Megha'],
    projectId: '1',
    isActive: true,
  ),
  const Meeting(
    id: '2',
    title: 'Sprint Planning',
    time: '2:00 PM',
    participants: ['Alex Morgan', 'Mike Johnson'],
    projectId: '1',
    isActive: false,
  ),
  const Meeting(
    id: '3',
    title: 'Design Review',
    time: '3:30 PM',
    participants: ['Alex Morgan', 'Sarah Chen'],
    projectId: '2',
    isActive: false,
  ),
];

final List<Reminder> reminders = [
  const Reminder(
    id: '1',
    title: 'Team Standup',
    description: 'Daily team sync-up meeting',
    type: 'meeting',
    time: 'Now',
    isRead: false,
    data: null,
  ),
  const Reminder(
    id: '2',
    title: 'New message from Rahul',
    description: 'In ProjectSync App general chat',
    type: 'chat',
    time: '5 minutes ago',
    isRead: false,
    data: null,
  ),
  const Reminder(
    id: '3',
    title: 'Sprint Planning meeting',
    description: 'Starting at 2:00 PM',
    type: 'meeting',
    time: '2 hours from now',
    isRead: true,
    data: null,
  ),
  const Reminder(
    id: '4',
    title: 'Project deadline: E-Commerce Platform',
    description: 'Due in 3 days',
    type: 'deadline',
    time: '3 days',
    isRead: true,
    data: null,
  ),
];
