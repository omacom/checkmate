#include "agentplayer.h"

#include <QFile>
#include <QRegularExpression>
#include <QStandardPaths>

namespace {
QString coordinates(Chess::Move move) {
  auto text = Chess::squareName(move.from) + Chess::squareName(move.to);
  if (move.promotion) text += char(std::tolower(" PNBRQK"[move.promotion]));
  return QString::fromStdString(text);
}
}

AgentPlayer::AgentPlayer(const QString &defaultsFile, QObject *parent) : QObject(parent), m_defaultsFile(defaultsFile) {
  m_timeout.setSingleShot(true);
  // Agents think for a while, and some start slowly; past this the turn is handed back to the player to decide.
  m_timeout.setInterval(180000);
  connect(&m_timeout,&QTimer::timeout,this,[this] { fail(tr("%1 took too long to answer.").arg(name())); });
}
AgentPlayer::~AgentPlayer() {
  m_timeout.stop();
  if (m_process) { m_process->disconnect(this); m_process->kill(); }
}

QString AgentPlayer::omarchyDefaultsFile() {
  return QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation) + "/omarchy/defaults/agent";
}
QString AgentPlayer::id() const {
  QFile file(m_defaultsFile);
  if (m_defaultsFile.isEmpty() || !file.open(QIODevice::ReadOnly)) return {};
  return QString::fromUtf8(file.readLine(256)).trimmed();
}
QString AgentPlayer::displayName(const QString &id) {
  static const QHash<QString,QString> names{
    {"claude","Claude Code"},{"codex","Codex"},{"opencode","OpenCode"},{"kilo","Kilo"},{"pi","Pi"},{"omp","Oh My Pi"},
    {"grok","Grok"},{"crush","Crush"},{"copilot","GitHub Copilot"},{"cursor-agent","Cursor CLI"},{"agy","Antigravity"},
    {"qwen","Qwen Code"},{"kimi","Kimi"},{"amp","Amp"},{"ori","Ori"},{"hermes","Hermes"},{"openclaw","OpenClaw"},
    {"muse","Muse Code"},{"dsh","DeepSeek Harness"},{"mcode","MiniMax Code"},{"kiro-cli","Kiro CLI"},{"freebuff","Freebuff"},
    {"devin","Devin CLI"},{"commandcode","Command Code"}};
  return names.value(id,id);
}
QStringList AgentPlayer::command(const QString &id, const QString &prompt) {
  // Each harness spells "answer once and exit" its own way. One that isn't here has no such mode we know of.
  if (id == "claude" || id == "pi" || id == "omp" || id == "grok" || id == "copilot" || id == "cursor-agent" || id == "agy" || id == "qwen")
    return {id,"-p",prompt};
  // Codex refuses to run outside a git repository unless told the folder is fine.
  if (id == "codex") return {id,"exec","--skip-git-repo-check",prompt};
  if (id == "opencode" || id == "kilo" || id == "crush") return {id,"run",prompt};
  if (id == "kimi") return {id,"--prompt",prompt};
  if (id == "amp") return {id,"--execute",prompt};
  if (id == "ori") return {id,"code","--prompt",prompt};
  return {};
}
bool AgentPlayer::available() const {
  if (!m_override.isEmpty()) return !id().isEmpty();
  const auto argv = command(id(),{});
  return !argv.isEmpty() && !QStandardPaths::findExecutable(argv.first()).isEmpty();
}
QString AgentPlayer::prompt(const Chess::Position &position, const QStringList &history, const QString &rejected) {
  QStringList played;
  for (int i = 0; i < history.size(); ++i) played << (i % 2 ? history[i] : QString::number(i / 2 + 1) + ". " + history[i]);
  QStringList legal;
  for (auto move : position.legal()) legal << coordinates(move);
  QString text = QString("You are playing chess as %1 and it is your move.\n\n").arg(position.white ? "White" : "Black");
  text += "Position (FEN): " + QString::fromStdString(position.fen()) + "\n";
  text += "Moves so far: " + (played.isEmpty() ? QString("none") : played.join(' ')) + "\n";
  text += "Your legal moves: " + legal.join(' ') + "\n\n";
  if (!rejected.isEmpty()) text += "Your last answer, \"" + rejected.left(80) + "\", named no move from that list.\n";
  text += "Pick the strongest move from the list and reply with that move alone, written exactly as it is in the list, such as " + legal.value(0) +
          ". Use no tools, read no files, and give no explanation.";
  return text;
}
bool AgentPlayer::parse(const QString &answer, const Chess::Position &position, Chess::Move *move) {
  const auto legal = position.legal();
  int best = -1;
  // The last move named wins: an agent that thinks aloud ends on its choice.
  static const QRegularExpression coordinate("(?<![a-z0-9])([a-h][1-8][a-h][1-8][qrbn]?)(?![a-z0-9])",QRegularExpression::CaseInsensitiveOption);
  for (auto found = coordinate.globalMatch(answer); found.hasNext();) {
    const auto match = found.next();
    for (auto candidate : legal) if (coordinates(candidate) == match.captured(1).toLower() && match.capturedStart() > best) { best = match.capturedStart(); *move = candidate; }
  }
  if (best >= 0) return true;
  for (auto candidate : legal) {
    QString san = QString::fromStdString(position.san(candidate));
    san.remove('+').remove('#');
    const QRegularExpression written("(?<![A-Za-z0-9])" + QRegularExpression::escape(san) + "(?![A-Za-z0-9=])");
    for (auto found = written.globalMatch(answer); found.hasNext();) {
      const auto match = found.next();
      if (match.capturedStart() > best) { best = match.capturedStart(); *move = candidate; }
    }
  }
  return best >= 0;
}
void AgentPlayer::ask(const Chess::Position &position, const QStringList &history) {
  cancel();
  m_position = position; m_history = history; m_retried = false;
  start({});
}
void AgentPlayer::start(const QString &rejected) {
  m_asked = name();
  const QString text = prompt(m_position,m_history,rejected);
  QStringList argv = m_override.isEmpty() ? command(id(),text) : m_override + QStringList{text};
  if (argv.isEmpty()) { fail(tr("%1 can't answer on its own yet. Choose another default agent, or play the computer.").arg(m_asked)); return; }
  m_process = std::make_unique<QProcess>();
  m_process->setWorkingDirectory(m_workspace.path());
  // Nothing to read on its input, so an agent that waits for one sees the end of it at once.
  m_process->setStandardInputFile(QProcess::nullDevice());
  connect(m_process.get(),&QProcess::finished,this,&AgentPlayer::finish);
  connect(m_process.get(),&QProcess::errorOccurred,this,[this](QProcess::ProcessError error) {
    if (error == QProcess::FailedToStart) fail(tr("%1 is not installed.").arg(m_asked));
  });
  m_timeout.start();
  m_process->start(argv.first(),argv.mid(1));
}
void AgentPlayer::finish(int exitCode, QProcess::ExitStatus status) {
  if (!m_process) return;
  m_timeout.stop();
  const QString answer = QString::fromUtf8(m_process->readAllStandardOutput());
  const QString complaint = QString::fromUtf8(m_process->readAllStandardError()).trimmed();
  m_process.release()->deleteLater();
  Chess::Move move;
  if (status == QProcess::NormalExit && exitCode == 0 && parse(answer,m_position,&move)) { emit answered(move); return; }
  if (status != QProcess::NormalExit || exitCode != 0) {
    // The agent's own last words say why: not signed in, out of credit, offline.
    const QString why = complaint.isEmpty() ? answer.trimmed() : complaint;
    fail(why.isEmpty() ? tr("%1 stopped without answering.").arg(m_asked) : tr("%1 stopped without answering: %2").arg(m_asked,why.section('\n',-1).left(200)));
    return;
  }
  if (!m_retried) { m_retried = true; start(answer.trimmed()); return; }
  fail(tr("%1 did not answer with a legal move.").arg(m_asked));
}
void AgentPlayer::fail(const QString &reason) {
  cancel();
  emit failed(reason);
}
void AgentPlayer::cancel() {
  m_timeout.stop();
  if (!m_process) return;
  auto process = m_process.release();
  process->disconnect(this);
  // Asked to stop, then stopped: the process is given its own time to end rather than blocking the window on it.
  connect(process,&QProcess::finished,process,&QObject::deleteLater);
  if (process->state() == QProcess::NotRunning) { process->deleteLater(); return; }
  process->terminate();
  QTimer::singleShot(2000,process,&QProcess::kill);
}
