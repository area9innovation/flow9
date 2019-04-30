#ifndef BEVELEFFECT_H
#define BEVELEFFECT_H
 
#include <stdint.h>
#include <QtGui>
#include <QGraphicsEffect>

class BevelEffect : public QGraphicsEffect
{
 Q_OBJECT

public:
    BevelEffect(qreal angle, uint offset, uint radius, uint color_up, qreal alpha_up, uint color_down, qreal alpha_down);

protected:
    void sourceChanged (ChangeFlags flags);
    virtual void draw( QPainter *painter );

    qreal    AlphaUp, AlphaDown;
    uint32_t ColorUp, ColorDown;
    qreal    Angle;
    uint32_t Offset, Radius;

    void MakeShadePixmap(const QPixmap &source);

private:
    QPixmap ShadePx;
};

#endif // BEVELEFFECT_H
