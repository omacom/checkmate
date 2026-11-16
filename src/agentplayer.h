#pragma once

#include "chess.h"
#include <QObject>
#include <QProcess>
#include <QStringList>
#include <QTemporaryDir>
#include <QTimer>
#include <memory>

// Plays a side by asking the user's default Omarchy agent for each move. Omarchy only opens agents in a
// terminal, so the agent's own one-shot mode is run here: one prompt in, one answer out.
class AgentPlayer : public QObject {
  Q_OBJECT
public:
  // Tests pass their own defaults file; an empty path means no agent is chosen.
  explicit AgentPlayer(const QString &defaultsFile, QObject *parent = nullptr);
  ~AgentPlayer() override;
  // Where `omarchy default agent` records the choice.
  static QString omarchyDefaultsFile();
  // The chosen agent's id as Omarchy writes it ("claude", "codex"), read fresh so a new choice is seen.
  QString id() const;
  QString name() const { return displayName(id()); }
  // Whether the chosen agent can answer on its own and is installed.
  bool available() const;
  static QString displayName(const QString &id);
  // The agent's one-shot command for a prompt, or nothing when it has no such mode we know of.
  static QStringList command(const QString &id, const QString &prompt);
  static QString prompt(const Chess::Position &position, const QStringList &history, const QString &rejected = {});
  // The last legal move the answer names, in coordinates (e7e5) or as written in the game (Nf6).
  static bool parse(const QString &answer, const Chess::Position &position, Chess::Move *move);
  void setDefaultsFile(const QString &path) { m_defaultsFile = path; }
  // Tests stand a script in for the agent: the prompt is added as its last argument.
  void setCommandOverride(const QStringList &command) { m_override = command; }
  void setTimeout(int milliseconds) { m_timeout.setInterval(milliseconds); }
  void ask(const Chess::Position &position, const QStringList &history);
  void cancel();
signals:
  void answered(Chess::Move move);
  void failed(const QString &reason);
private:
  void start(const QString &rejected);
  void finish(int exitCode, QProcess::ExitStatus status);
  void fail(const QString &reason);
  QString m_defaultsFile;
  QStringList m_override;
  std::unique_ptr<QProcess> m_process;
  // The agent works in an empty folder of its own, never among the user's files.
  QTemporaryDir m_workspace;
  QTimer m_timeout;
  Chess::Position m_position;
  QStringList m_history;
  QString m_asked;
  bool m_retried = false;
};
