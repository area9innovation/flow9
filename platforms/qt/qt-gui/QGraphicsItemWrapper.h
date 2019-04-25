#ifndef QGRAPHICSITEMWRAPPER_H
#define QGRAPHICSITEMWRAPPER_H

//
// We need a wrapper because QGraphicsItem does not inherit QObject and
// doesnot support meta - information
//

#include <QtGui>
#include <QGraphicsItem>

class QGraphicsItemWrapper : public QObject
{
    Q_OBJECT

public:
    QGraphicsItemWrapper(QGraphicsItem *item);

    QGraphicsItem *GraphicsItem;
};

#endif // QGRAPHICSITEMWRAPPER_H
