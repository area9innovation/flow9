/***************************************************************************
                          flow_parser.cpp  -  description
                             -------------------
    begin                : Apr 9 2018
    author               : 2018 Dmitry Vlasov
    email                : dmitry.vlasov.2@area9.dk
 ***************************************************************************/
 /***************************************************************************
 *                                                                         *
 *   This program is free software; you can redistribute it and/or modify  *
 *   it under the terms of the GNU General Public License as published by  *
 *   the Free Software Foundation; either version 2 of the License, or     *
 *   (at your option) any later version.                                   *
 *                                                                         *
 ***************************************************************************/
#include "plugin_katesymbolviewer.h"

void KatePluginSymbolViewerView::parseFlowSymbols(void) {
  if (!m_mainWindow->activeView()) {
    return;
  }

  m_macro->setText(i18n("Show Globals"));
  m_struct->setText(i18n("Show Types"));
  m_func->setText(i18n("Show Functions"));

  static QPixmap unionPixmap(class_xpm);
  static QPixmap structPixmap(struct_xpm);
  static QPixmap functionPixmap(method_xpm);
  static QPixmap functionDeclPixmap(macro_xpm);
  static QPixmap globalPixmap(class_int_xpm);

  QTreeWidgetItem* globalNode = nullptr;
  QTreeWidgetItem* typeNode = nullptr;
  QTreeWidgetItem* functionNode = nullptr;

  QTreeWidgetItem* lastGlobalNode = nullptr;
  QTreeWidgetItem* lastTypeNode = nullptr;
  QTreeWidgetItem* lastFunctionNode = nullptr;

  if (m_treeOn->isEnabled()) {
    globalNode = new QTreeWidgetItem(m_symbols, QStringList(i18n("Globals")));
    typeNode = new QTreeWidgetItem(m_symbols, QStringList(i18n("Types")));
    functionNode = new QTreeWidgetItem(m_symbols, QStringList(i18n("Functions")));
    globalNode->setIcon(0, QIcon(globalPixmap));
    typeNode->setIcon(0, QIcon(structPixmap));
    functionNode->setIcon(0, QIcon(functionPixmap));

    if (m_expandOn->isEnabled()) {
      m_symbols->expandItem(globalNode);
      m_symbols->expandItem(typeNode);
      m_symbols->expandItem(functionNode);
    };
    lastGlobalNode = globalNode;
    lastTypeNode = typeNode;
    lastFunctionNode = functionNode;
    m_symbols->setRootIsDecorated(1);
  } else {
    m_symbols->setRootIsDecorated(0);
  }

  static QRegExp funcDefRegExp(QLatin1String("^([a-z][a-zA-Z0-9_]*)\\s*\\([^\\)]*\\).*"));
  static QRegExp funcDeclRegExp(QLatin1String("^\\s*([a-z][a-zA-Z0-9_]*)\\s*\\(([^\\)]*\\)[^\\{]*;)?\\s*"));
  static QRegExp structRegExp(QLatin1String("^\\s*([A-Z][a-zA-Z0-9_]*)\\s*:?\\s*\\(([^\\)]*\\)\\s*;?\\s*|\\s*)$"));
  static QRegExp unionRegExp(QLatin1String("^\\s*([A-Z][a-zA-Z0-9_]*)\\s*::=.*$"));
  static QRegExp funcDefEndRegExp(QLatin1String("^\\}\\s*$"));
  static QRegExp globalRegExp(QLatin1String("^([a-z][a-zA-Z0-9_]*)\\s*=.*"));

  bool inFunctionDef = false;
  KTextEditor::Document *kv = m_mainWindow->activeView()->document();
  for (int i = 0; i < kv->lines(); ++i) {
    QString line = kv->line(i);
    if (line.length() == 0) {
    	continue;
    }
    if (funcDefEndRegExp.exactMatch(line)) {
    	inFunctionDef = false;
    } else if (funcDefRegExp.exactMatch(line)) {
    	if (m_treeOn->isEnabled()) {
    		lastFunctionNode = new QTreeWidgetItem(functionNode, lastFunctionNode);
            if (m_expandOn->isEnabled()) {
            	m_symbols->expandItem(lastFunctionNode);
            }
    	} else {
    		lastFunctionNode = new QTreeWidgetItem(m_symbols);
    	}
        lastFunctionNode->setText(0, funcDefRegExp.cap(1));
        lastFunctionNode->setIcon(0, QIcon(functionPixmap));
        lastFunctionNode->setText(1, QString::number(i));
        inFunctionDef = true;
    } else if (!inFunctionDef && funcDeclRegExp.exactMatch(line)) {
    	if (m_treeOn->isEnabled()) {
    		lastFunctionNode = new QTreeWidgetItem(functionNode, lastFunctionNode);
            if (m_expandOn->isEnabled()) {
            	m_symbols->expandItem(lastFunctionNode);
            }
    	} else {
    		lastFunctionNode = new QTreeWidgetItem(m_symbols);
    	}
        lastFunctionNode->setText(0, funcDeclRegExp.cap(1));
        lastFunctionNode->setIcon(0, QIcon(functionDeclPixmap));
        lastFunctionNode->setText(1, QString::number(i));
    } else if (!inFunctionDef && structRegExp.exactMatch(line)) {
    	if (m_treeOn->isEnabled()) {
    		lastTypeNode = new QTreeWidgetItem(typeNode, lastTypeNode);
            if (m_expandOn->isEnabled()) {
            	m_symbols->expandItem(lastTypeNode);
            }
    	} else {
    		lastTypeNode = new QTreeWidgetItem(m_symbols);
    	}
        lastTypeNode->setText(0, structRegExp.cap(1));
        lastTypeNode->setIcon(0, QIcon(structPixmap));
        lastTypeNode->setText(1, QString::number(i));
    } else if (!inFunctionDef && unionRegExp.exactMatch(line)) {
    	if (m_treeOn->isEnabled()) {
    		lastTypeNode = new QTreeWidgetItem(typeNode, lastTypeNode);
            if (m_expandOn->isEnabled()) {
            	m_symbols->expandItem(lastTypeNode);
            }
    	} else {
    		lastTypeNode = new QTreeWidgetItem(m_symbols);
    	}
        lastTypeNode->setText(0, unionRegExp.cap(1));
        lastTypeNode->setIcon(0, QIcon(unionPixmap));
        lastTypeNode->setText(1, QString::number(i));
    } else if (!inFunctionDef && globalRegExp.exactMatch(line)) {
    	if (m_treeOn->isEnabled()) {
    		lastGlobalNode = new QTreeWidgetItem(globalNode, lastGlobalNode);
            if (m_expandOn->isEnabled()) {
            	m_symbols->expandItem(lastTypeNode);
            }
    	} else {
    		lastGlobalNode = new QTreeWidgetItem(m_symbols);
    	}
        lastGlobalNode->setText(0, globalRegExp.cap(1));
        lastGlobalNode->setIcon(0, QIcon(globalPixmap));
        lastGlobalNode->setText(1, QString::number(i));
    }
  }
}
