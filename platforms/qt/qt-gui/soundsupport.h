#ifndef SOUNDSUPPORT_H
#define SOUNDSUPPORT_H

#include "utils/AbstractSoundSupport.h"
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QMediaPlayer>

class QtSound : public QObject, public AbstractSound
{
    Q_OBJECT

protected:
    friend class QtSoundChannel;
    QMediaPlayer *player;
    QNetworkReply *reply;
    QByteArray data;

public:
    QtSound(AbstractSoundSupport *owner) : AbstractSound(owner), player(NULL), reply(NULL) {}
    ~QtSound() { delete player; }

    virtual void beginLoad(unicode_string url, StackSlot onFail, StackSlot onReady);
    virtual float computeSoundLength();

    DEFINE_FLOW_NATIVE_OBJECT(QtSound, AbstractSound);

private slots:
    void finished();
    void handleError(QMediaPlayer::Error error);
    void handleMediaStatusChanged(QMediaPlayer::MediaStatus status);
};

class QtSoundChannel : public QObject, public AbstractSoundChannel
{
    Q_OBJECT

protected:
    QMediaPlayer *player;
    bool looping;

    virtual void setVolume(float value);
    virtual void stopSound();
    virtual float getSoundPosition();

private slots:
    void handleStateChanged(QMediaPlayer::State state);

public:
    QtSoundChannel(AbstractSoundSupport *owner, AbstractSound *snd)
        : AbstractSoundChannel(owner, snd), player(NULL), looping(false)
    {}

    virtual void beginPlay(float start_pos, bool loop, StackSlot onDone);

    DEFINE_FLOW_NATIVE_OBJECT(QtSoundChannel, AbstractSoundChannel);
};

class QtSoundSupport : public QObject, public AbstractSoundSupport
{
    Q_OBJECT

    friend class QtSound;
    QNetworkAccessManager *manager;

public:
    QtSoundSupport(ByteCodeRunner *Runner);

protected:
    virtual AbstractSound *makeSound() { return new QtSound(this); }
    virtual AbstractSoundChannel *makeSoundChannel(AbstractSound *sound) { return new QtSoundChannel(this, sound); }
};

#endif // SOUNDSUPPORT_H
