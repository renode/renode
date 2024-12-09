#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
# Copyright (C) 2024 Antmicro
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# SPDX-License-Identifier: Apache-2.0

from typing import Any, Optional, Iterable, Union, TypeVar, Callable
from enum import Enum
from contextlib import contextmanager

from itertools import chain
from functools import partial

_T = TypeVar('_T')

def intersperse(it: Iterable[_T], s: _T) -> Iterable[_T]:
    add_s = False
    while True:
        try:
            v = it.__next__()
        except StopIteration:
            return
        if add_s:
            yield s
        yield v
        add_s = True

class CodeCC(Enum):
    NEST = 0
    UNNEST = 1
    COMMENT_BEGIN = 2
    COMMENT_END = 3
    COMMENT_MODE_SET_INLINE = 4
    COMMENT_MODE_RESTORE = 5
    DOC_BEGIN = 6
    DOC_END = 7

class AstException(Exception):
    def __init__(self):
        super().__init__()

class AstWrongTypeException(AstException):
    def __init__(self, got: type, expected: type) -> None:
        super().__init__()
        self.got = got
        self.expected = expected

    def __str__(self) -> str:
        return f'Expected type `{self.expected}`, got `{self.got}`'

def expect_type(obj: Any, ty: type) -> Any:
    if type(obj) is not ty:
        raise AstWrongTypeException(type(obj), ty)
    return Any

class Node:
    def __init__(self, name: Optional[str] = None,
                 parent: Optional[tuple['Node', str]] = None,
                 previous: Optional['Node'] = None,
                 next: Optional['Node'] = None,
                 indents: bool = True,
                 comment: Optional[str] = None,
                 doc: Optional[str] = None):
        self.name = name if name is not None else '<anonymous>'
        self.indents = indents
        self.m_parent = parent
        self.m_previous = previous
        self.m_next = next
        self.m_comment = comment
        self.m_doc = doc

    def get_hierarchical_name(self):
        if self.parent:
            return self.generate_reference(self.parent) + '.' + self.name
        return self.name

    @property
    def parent(self) -> Optional[tuple['Node', str]]:
        return self.m_parent

    @parent.setter
    def parent(self, value: tuple['Node', str]):
        if self.m_parent is not None:
            raise RuntimeError(f'Node {self.name} of type {type(self)} '
                               f'has a parent of type {type(self.parent[0])}'
                                'already attached')
        if self.m_previous is not None:
            raise RuntimeError('Node can\'t have a predecessor and a parent at the same time')
        self.m_parent = value

    @parent.deleter
    def parent(self):
        self.m_parent = None

    def get_parent(self) -> Optional[tuple['Node', str]]:
        return self.first().parent

    def children(self) -> Iterable['Node']:
        return []

    def tokenize(self, cg: 'CodeGenerator') -> Iterable[Union[str, CodeCC]]:
        raise RuntimeError('Abstract codegen')

    def m_path_to_root(self) -> list['Node']:
        n = self
        path_to_root = []
        while n is not None:
            path_to_root.append(n)
            n = n.parent[0]

    @property
    def null(self) -> bool: return False

    def detach(self) -> 'Node':
        if self.previous is None and self.parent is None:
            raise RuntimeError('Node is already detached')


        if self.parent is not None:
            setattr(self.parent[0], self.parent[1], NullNode())

        del(self.previous)
        del(self.parent)

        return self

    def cut(self) -> 'Node':
        if self.next is None:
            return self.detach()
        tail = self.m_next.detach()
        self.replace(tail)
        return self

    @property
    def previous(self) -> Optional['Node']:
        return self.m_previous

    @previous.setter
    def previous(self, node: 'Node') -> None:
        if self.m_previous is not None:
            raise RuntimeError(f'Node {self.name} of type {type(self)} '
                               f'has a predecessor {self.previous.name} '
                               f'of type {type(self.previous)} already attached')
        if self.m_parent is not None:
            raise RuntimeError('Node can\'t have a predecessor and a parent at the same time')
        self.m_previous = node

    @previous.deleter
    def previous(self) -> None:
        if self.m_previous is not None:
            self.m_previous.m_next = None
            self.m_previous = None

    @property
    def next(self) -> Optional['Node']:
        return self.m_next

    @next.setter
    def next(self, node: 'Node') -> None:
        if self.m_next is not None:
            raise RuntimeError(f'Node {self.name} of type {type(self)} '
                               f'has a successor {self.m_next.name} '
                               f'of type {type(self.m_next)} already attached')
        self.m_next = node

    @next.deleter
    def next(self) -> None:
        if self.m_next is not None:
            self.m_previous = None
            self.m_next = None

    def first(self) -> 'Node':
        first = self
        while True:
            if first.previous is None:
                return first
            first = first.previous

    def last(self) -> 'Node':
        last = self
        while True:
            if last.next is None:
                return last
            last = last.next

    def replace(self, node: 'Node') -> None:
        if not self.previous and not self.parent:
            raise RuntimeError('No links to replace')
        if self.previous:
            prev = self.previous
            del(self.previous)
            prev.next = node
        elif self.parent:
            (parent, field) = self.parent
            del(self.parent)
            node.parent = (parent, field)
            setattr(parent, field, node)
        tail = self.next
        del(self.next)
        if tail is not None:
            node.last().append(tail)

    def append(self, node: 'Node', insert: bool = False) -> None:
        last = node.last()

        if self.next is not None:
            if not insert:
                raise RuntimeError('Node is already linked')
            next = self.next
            if insert:
                del(self.next)
                last.next = next
        self.next = node
        node.previous = self

    def then(self, node: 'Node') -> 'Node':
        self.last().append(node)
        return self

    def iterate(self) -> Iterable['Node']:
        node = self
        while node is not None:
            next = node.next # Keep the original next in case we replaced the node
            yield node
            node = next

    @staticmethod
    def join(nodes: Optional[Iterable['Node']]) -> 'Node':
        if nodes is None: return NullNode()

        it = nodes.__iter__()
        try:
            node = it.__next__()
        except StopIteration:
            return NullNode()

        first = node
        last = node.last()
        while True:
            try:
                node = it.__next__()
            except StopIteration:
                break
            last.append(node)
            last = node.last()

        return first

    @staticmethod
    def or_null(node: Optional[_T]) -> Union[_T, 'NullNode']:
        if node is None: return NullNode()
        return node

    def emit_comment_tokens(self, inline: bool = False) -> list[Union[str, CodeCC]]:
        tokens = []

        if self.m_doc is not None:
            tokens += [CodeCC.DOC_BEGIN, self.m_doc, CodeCC.DOC_END]

        if self.m_comment is not None:
            if inline: tokens.append(CodeCC.COMMENT_MODE_SET_INLINE)
            tokens += [CodeCC.COMMENT_BEGIN, self.m_comment, CodeCC.COMMENT_END]
            if inline: tokens.append(CodeCC.COMMENT_MODE_RESTORE)

        return tokens

    def __str__(self) -> str:
        return CodeGenerator.emit(self)

class NullNode(Node):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)

    def iterate(self) -> Iterable['Node']:
        return []

    def append(self, node: Node, insert: bool = False) -> None:
        return self.replace(node)

    @property
    def null(self) -> bool: return True

class CodeGenerator:
    def __init__(self):
        self.m_indent = 0
        self.m_s = ''
        self.m_namespace: list['Namespace'] = []
        self.m_comment_inline = 0

    def generate_reference(self, node: Node) -> str:
        # TODO: Take context into account
        parent = node.get_parent()
        if parent:
            return self.generate_reference(parent[0]) + '.' + node.name
        return node.name

    @contextmanager
    def enter_namespace(self, namespace: 'Namespace'):
        self.m_namespace.append(namespace)
        try:
            yield
        finally:
            self.m_namespace.pop()

    def m_add_indent(self):
        if len(self.m_s) != 0 and self.m_s[-1] == '\n':
            self.m_s += '    ' * self.m_indent

    @staticmethod
    def emit(node: Node, comments: bool = False, docs: bool = True) -> str:
        cg = CodeGenerator()

        for token in node.tokenize(cg):
            match token:
                case str(code):
                    for line in code.splitlines(keepends=True):
                        cg.m_add_indent()
                        cg.m_s += line
                case CodeCC.NEST:
                    if node.indents:
                        cg.m_indent += 1
                case CodeCC.UNNEST:
                    if node.indents:
                        cg.m_indent -= 1
                case CodeCC.COMMENT_MODE_SET_INLINE:
                    cg.m_comment_mode += 1
                case CodeCC.COMMENT_MODE_RESTORE:
                    cg.m_comment_mode -= 1
                case CodeCC.COMMENT_BEGIN:
                    if comments:
                        if cg.m_comment_inline:
                            cg.m_s += '/* '
                        else:
                            cg.m_add_indent()
                            cg.m_s += '// '
                case CodeCC.COMMENT_END:
                    if comments: cg.m_s += '\n' if cg.m_comment_inline == 0 else ' */'
                case CodeCC.DOC_BEGIN:
                    if docs:
                        cg.m_add_indent()
                        cg.m_s += '/// <summary> '
                case CodeCC.DOC_END:
                    if docs: cg.m_s += ' </summary>\n'
                case _ as invalid:
                    raise RuntimeError(f'Invalid code control: {invalid}')

        return cg.m_s;

class HardCode(Node):
    def __init__(self, code: str, **kwargs) -> None:
        super().__init__(**kwargs)
        self.code = code

    def tokenize(self, _: CodeGenerator) -> str:
        return self.emit_comment_tokens(inline=True) + [self.code]

def TypeMetaClass(name, bases, attrs: dict):
    ret = type(name, bases, attrs)

    setattr(ret, 'sbyte', ret('sbyte', 8))
    setattr(ret, 'byte', ret('byte', 8))
    setattr(ret, 'short', ret('short', 16))
    setattr(ret, 'ushort', ret('ushort', 16))
    setattr(ret, 'int', ret('int', 32))
    setattr(ret, 'uint', ret('uint', 32))
    setattr(ret, 'long', ret('long', 64))
    setattr(ret, 'ulong', ret('ulong', 64))
    setattr(ret, 'bool', ret('bool', 8))
    setattr(ret, 'string', ret('string'))

    return ret

class Type(Node, metaclass=TypeMetaClass):
    sbyte: 'Type'
    byte: 'Type'
    short: 'Type'
    ushort: 'Type'
    int: 'Type'
    uint: 'Type'
    long: 'Type'
    ulong: 'Type'
    bool: 'Type'
    string: 'Type'

    @property
    def width(self) -> Optional[int]:
        return self.width_

    @property
    def is_long(self) -> bool:
        return self.width > 32 if self.width is not None else False

    @property
    def is_unsigned(self) -> bool:
        return self in [Type.byte, Type.ushort, Type.uint, Type.ulong]

    def __init__(self, name: str, width: Optional[int] = None, **kwargs):
        super().__init__(name=name, **kwargs)
        self.width_ = width

    def __eq__(self, other) -> bool:
        return self.name == other.name

    def array(self) -> 'Type':
        return Type(self.name + '[]')

    def tokenize(self, _: CodeGenerator) -> Iterable[Union[str, CodeCC]]:
        return self.emit_comment_tokens() + [self.name]

class Expr(Node):
    def __init__(self, ty: Type, **kwargs):
        super().__init__(**kwargs)
        self.type = ty

    def into_stmt(self) -> 'StmtExpr':
        return StmtExpr(self)

class HardExpr(Expr):
    def __init__(self, code: str, ty: Type, **kwargs) -> None:
        super().__init__(ty=ty, **kwargs)
        self.code = code

    def tokenize(self, _: CodeGenerator) -> str:
        return self.emit_comment_tokens() + [self.code]

class IntLit(Expr):
    def __init__(self, value: int, unsigned: bool = False, long: bool = False,
                 fmt: str = 'd', **kwargs):
        match (unsigned, long):
            case (False, False):
                super().__init__(ty=Type.int, **kwargs)
            case (False, True):
                super().__init__(ty=Type.long, **kwargs)
            case (True, False):
                super().__init__(ty=Type.uint, **kwargs)
            case (True, True):
                super().__init__(ty=Type.ulong, **kwargs)

        self.value = value
        self.fmt = fmt

    def tokenize(self, _: CodeGenerator) -> Iterable[str | CodeCC]:
        match self.fmt:
            case 'd': s = str(self.value)
            case 'h': s = hex(self.value)
            case _: raise RuntimeError(f'Invalid integer format `{self.fmt}`')

        if self.type in [Type.ulong, Type.uint, Type.ushort, Type.byte]:
            s += 'U'
        if self.type in [Type.long, Type.ulong]:
            s += 'L'

        return self.emit_comment_tokens() + [s]

class StringLit(Expr):
    def __init__(self, value: str, **kwargs):
        super().__init__(ty=Type.string, **kwargs)
        self.value = value

    def tokenize(self, _: CodeGenerator) -> Iterable[str | CodeCC]:
        return self.emit_comment_tokens(inline=True) + \
            ['"' + self.value.replace('"', '\"') + '"']

class Arg(Node):
    def __init__(self, value: Any, name: Optional[str] = None,
                 out: bool = False, **kwargs) -> None:
        super().__init__(name=name, **kwargs)
        self.named = name is not None
        self.value = value
        self.out = out

    def tokenize(self, _: CodeGenerator) -> Iterable[Union[str, CodeCC]]:
        s = ''
        if self.named:
            s += f'{self.name}: '
        if self.out:
            s += f'out '

        s += str(self.value)

        return self.emit_comment_tokens(inline=True) + [s]

class BoolLit(Expr):
    def __init__(self, value: bool, **kwargs) -> None:
        super().__init__(ty=Type.bool, **kwargs)
        self.m_value = value

    @property
    def value(self) -> bool: return self.m_value

    def tokenize(self, _: CodeGenerator) -> str:
        return self.emit_comment_tokens(inline=True) + ['true' if self.value else 'false']

class Stmt(Node):
    def __init__(self, **kwargs) -> None:
        super().__init__(**kwargs)

class StmtExpr(Stmt):
    def __init__(self, expr: Expr, **kwargs) -> None:
        super().__init__(**kwargs)
        self.m_expr = expr
        expr.parent = (self, 'expr')

    @property
    def expr(self) -> Expr: return self.expr

    def children(self) -> Iterable[Node]:
        return [self.m_expr]

    def tokenize(self, cg: CodeGenerator) -> Iterable[str | CodeCC]:
        return chain(self.emit_comment_tokens(), self.m_expr.tokenize(cg), [';\n'])

class VariableRef(Expr):
    def __init__(self, decl: 'VariableDecl', **kwargs):
        super().__init__(ty=decl.type, **kwargs)
        self.decl = decl

    def tokenize(self, cg: CodeGenerator) -> Iterable[Union[str, CodeCC]]:
        return self.emit_comment_tokens() + [self.decl.name]

def AccessibilityModMetaClass(name, bases, attrs: dict):
    ret = type(name, bases, attrs)
    setattr(ret, 'PUBLIC', ret(1))
    setattr(ret, 'INTERNAL', ret(2))
    setattr(ret, 'PROTECTED', ret(3))
    setattr(ret, 'PRIVATE', ret(4))
    return ret

class AccessibilityMod(Node, metaclass=AccessibilityModMetaClass):
    PUBLIC: 'AccessibilityMod'
    INTERNAL: 'AccessibilityMod'
    PROTECTED: 'AccessibilityMod'
    PRIVATE: 'AccessibilityMod'

    def __init__(self, value: int, **kwargs) -> None:
        super().__init__(**kwargs)
        self.value = value

    def __eq__(self, value: 'AccessibilityMod') -> bool:
        return self.value == value.value

    def tokenize(self, _: CodeGenerator) -> Iterable[Union[str, CodeCC]]:
        match self:
            case AccessibilityMod.PUBLIC: tokens = ['public']
            case AccessibilityMod.INTERNAL: tokens = ['internal']
            case AccessibilityMod.PROTECTED: tokens = ['protected']
            case AccessibilityMod.PRIVATE: tokens = ['private']
            case _: raise RuntimeError('Invalid AccessibilityMod')

        return self.emit_comment_tokens(inline=True) + tokens

class VariableDecl(Stmt):
    def __init__(self, name: str, ty: Type, init: Optional[Expr] = None,
                 access: Optional[AccessibilityMod] = None, **kwargs):
        super().__init__(name=name, **kwargs)
        self.type = ty
        self.init = init
        self.access = access

    def ref(self) -> VariableRef:
        return VariableRef(self)

    def tokenize(self, cg: CodeGenerator) -> Iterable[Union[str, CodeCC]]:
        return chain(
            self.emit_comment_tokens(),
            [str(self.access) + ' '] if self.access is not None else '',
            self.type.tokenize(cg),
            [' ' + self.name],
            *(chain([' = '], self.init.tokenize(cg)) if self.init is not None else []),
            [';\n']
        )

class ArgDecl(VariableDecl):
    def __init__(self, name: str, ty: Type, out: bool = False,
                 default: Any = None, **kwargs) -> None:
        super().__init__(name=name, ty=ty, **kwargs)

        self.type = ty
        self.out = out
        self.default = default

    def tokenize(self, _: CodeGenerator) -> Iterable[str | CodeCC]:
        s = str(self.type)
        if self.out:
            s += ' out'
        s += ' ' + self.name

        if self.default:
            s += f' = {self.default}'

        return self.emit_comment_tokens(inline=True) + [s]

class InvokableDefinition(Node):
    def __init__(self, ret_ty: Optional[Type] = None,
                 static: bool = False, override: bool = False,
                 virtual: bool = False, abstract: bool = False,
                 partial: bool = False,
                 access: Optional[AccessibilityMod] = None, **kwargs) -> None:
        super().__init__(**kwargs)

        self.ret_type = ret_ty
        self.static = static
        self.virtual = virtual
        self.override = override
        self.abstract = abstract
        self.partial = partial
        self.access = access

    @property
    def p_prefix(self) -> str:
        prefix = ''
        if self.partial: prefix += 'partial '
        if self.static: prefix += 'static '
        if self.override: prefix += 'override '
        if self.virtual: prefix += 'virtual '
        if self.abstract: prefix += 'abstract '
        return prefix

    @staticmethod
    def p_definition_tail(
        cg: CodeGenerator,
        body: Optional[Union[StmtExpr]]
    ) -> Iterable[Union[str, CodeCC]]:
        if body is not None:
            return chain(
                ['\n{\n', CodeCC.NEST],
                *map(lambda s: s.tokenize(cg), body.iterate()),
                [CodeCC.UNNEST, '}\n']
            )
        return [';\n']

class MethodDefinition(InvokableDefinition):
    def __init__(self, name: str,
                 args: Optional[ArgDecl] = None,
                 body: Optional[Union[StmtExpr]] = None,
                 constructor: bool = False,
                 access: Optional[AccessibilityMod] = None,
                 **kwargs) -> None:
        super().__init__(name=name, access=access, **kwargs)

        self.args = args if args is not None else NullNode()
        self.body = body
        self.ctor = constructor

        if args is not None: args.parent = (self, 'args')
        if body is not None: body.parent = (self, 'body')

    def children(self) -> Iterable[Node]:
        if self.body is not None:
            return chain(self.args.iterate(), self.body.iterate())
        return self.args.iterate()

    def tokenize(self, cg: CodeGenerator) -> Iterable[str | CodeCC]:
        match (self.ret_type, self.ctor):
            case (Type() as ret_ty, False): return_ty_prefix = str(ret_ty) + ' '
            case (None, False): return_ty_prefix = 'void '
            case (None, True): return_ty_prefix = ''
            case _: raise RuntimeError('Invalid method return type configuration')

        prefix = self.p_prefix + return_ty_prefix

        tail = InvokableDefinition.p_definition_tail(cg, self.body)

        return chain(
            self.emit_comment_tokens(),
            [str(self.access) + ' '] if self.access is not None else '',
            [f'{prefix}{self.name}(' + ', '.join(str(arg) for arg in self.args.iterate()) + ')'],
            tail
        )

class PropertyDefintion(InvokableDefinition):
    def __init__(self, name: str, get: Union[bool, StmtExpr] = False,
                 set: Union[bool, StmtExpr] = False,
                 access: Optional[AccessibilityMod] = None, **kwargs) -> None:
        super().__init__(name=name, access=access, **kwargs)

        self.get = get
        self.set = set

        if isinstance(get, Node): get.parent = (self, 'get')
        if isinstance(set, Node): set.parent = (self, 'set')

    def children(self) -> Iterable[Node]:
        return chain(
            self.get.iterate() if isinstance(self.get, Node) else [],
            self.set.iterate() if isinstance(self.set, Node) else []
        )

    def tokenize(self, cg: CodeGenerator) -> Iterable[str | CodeCC]:
        code = self.emit_comment_tokens() + \
            ([str(self.access) + ' '] if self.access is not None else [' ']) + \
            [f'{self.p_prefix}{self.ret_type} {self.name} ' + '{']

        indent = type(self.set) is not bool or type(self.get) is not bool

        if indent:
            code[-1] += '\n'
            code.append(CodeCC.NEST)

        def make_body(accessor: Union[bool, Stmt], name: str):
            match accessor:
                case True:
                    if not indent: code[-1] += ' '
                    code.append(name + ';')
                    if indent: code[-1] += '\n'
                case Node() as get_body:
                    code.append(name)
                    code.extend(InvokableDefinition.p_definition_tail(cg, get_body))

        make_body(self.get, 'get')
        make_body(self.set, 'set')

        if indent:
            code.append(CodeCC.UNNEST)
            code.append('}\n')
        else:
            code.append(' }\n')

        return code

class Call(Expr):
    def __init__(self, method: Union[str | MethodDefinition], *arguments: Arg,
                 ret_ty: Optional[Type] = None,
                 object: Optional[Node] = None,
                 breakline: bool = False, **kwargs) -> None:

        match (method, ret_ty):
            case (str() as name, Type() | None as ty):
                super().__init__(ty=ret_ty, **kwargs)
                self.method_name = name
            case (MethodDefinition() as m, None):
                super().__init__(ty=m.ret_type, **kwargs)
                self.method_name = m.name
            case _:
                raise RuntimeError('Invalid call method reference')

        self.arguments = Node.join(arguments)
        self.object = object
        self.breakline = breakline

        if len(arguments) != 0: self.arguments.parent = (self, 'arguments')

    def children(self) -> Iterable[Node]:
        return self.arguments.iterate()

    def tokenize(self, cg: CodeGenerator) -> Iterable[Union[str, CodeCC]]:
        call = [self.method_name + \
                '(' + ', '.join(str(arg) for arg in self.arguments.iterate()) + ')']
        if self.object is None: return call

        nested = False
        sep = []
        if self.breakline:
            sep.append('\n')
            if not self.object is Call or self.object.object is None:
                nested = True
                sep.append(CodeCC.NEST)
        sep.append('.')

        tokens = chain(self.object.tokenize(cg), sep, call, [CodeCC.UNNEST] if nested else [])
        return chain(self.emit_comment_tokens(not self.breakline), tokens)

class Class(Node):
    def __init__(self, name: str,
                 fields: Optional[VariableDecl] = None,
                 properties: Optional[PropertyDefintion] = None,
                 methods:Optional[MethodDefinition] = None,
                 classes: Optional['Class'] = None,
                 derives: Optional[list[tuple[Optional[AccessibilityMod], 'Class']]] = None,
                 abstract: bool = False, partial: bool = False,
                 struct: bool = False,
                 access: Optional[AccessibilityMod] = None, **kwargs
    ) -> None:
        super().__init__(name=name, **kwargs)

        self.fields = Node.or_null(fields)
        self.properties = Node.or_null(properties)
        self.methods = Node.or_null(methods)
        self.classes = Node.or_null(classes)
        self.derives = derives if derives is not None else []
        self.abstract = abstract
        self.partial = partial
        self.struct = struct
        self.access = access

        self.fields.parent = (self, 'members')
        self.properties.parent = (self, 'properties')
        self.methods.parent = (self, 'method')
        self.classes.parent = (self, 'classes')

    @property
    def type(self) -> Type:
        return Type(self.name)

    def children(self) -> Iterable[Node]:
        return chain(
            self.fields.iterate(),
            self.properties.iterate(),
            self.methods.iterate(),
            self.classes.iterate()
        )

    def tokenize(self, cg: CodeGenerator) -> Iterable[Union[str, CodeCC]]:
        def with_access(access: AccessibilityMod, node: Node):
            if access is not None:
                return chain([str(access), ' '], node.tokenize(cg))
            return node.tokenize(cg)

        header = [str(self.access) + ' '] if self.access is not None else  ['']
        if self.abstract: header[-1] += 'partial '
        if self.partial: header[-1] += 'partial '
        header[-1] += ('struct ' if self.struct else 'class ') + self.name
        if len(self.derives) != 0:
            header = chain(
                header,
                [' : '],
                *intersperse((with_access(a, c.type) for a, c in self.derives), [', '])
            )
        header = chain(header, ['\n{\n'])

        return chain(
            self.emit_comment_tokens(),
            header,
            [CodeCC.NEST],
            *(f.tokenize(cg) for f in self.fields.iterate()),
            '\n' if not self.properties.null else '',
            *(p.tokenize(cg) for p in self.properties.iterate()),
            '\n' if not self.methods.null else '',
            *intersperse((m.tokenize(cg) for m in self.methods.iterate()), '\n'),
            '\n' if not self.classes.null else '',
            *intersperse((c.tokenize(cg) for c in self.classes.iterate()), '\n'),
            [CodeCC.UNNEST, '}\n']
        )

class Namespace(Node):
    def __init__(self, name: str,
                 namespaces: Optional[list['Namespace']] = None,
                 classes: Optional[Class] = None,
                 **kwargs):
        super().__init__(name=name, **kwargs)

        self.namespaces = Node.join(namespaces)
        self.classes = Node.or_null(classes)

        if namespaces is not None: self.namespaces.parent = (self, 'namespaces')
        if classes is not None: self.classes.parent = (self, 'classes')

    def children(self) -> Iterable[Node]:
        return chain(self.namespaces.iterate(), self.classes.iterate())

    def tokenize(self, cg: CodeGenerator) -> Iterable[str | CodeCC]:
        fullname = cg.generate_reference(self)
        with cg.enter_namespace(self):
            return chain(
                self.emit_comment_tokens(),
                [f'namespace {fullname}\n', '{\n', CodeCC.NEST],
                *intersperse((c.tokenize(cg) for c in self.classes.iterate()), '\n'),
                '\n' if not self.namespaces.null else '',
                *intersperse((n.tokenize(cg) for n in self.namespaces.iterate()), '\n'),
                [CodeCC.UNNEST, '}\n']
            )

class New(Expr):
    def __init__(self, ty: Type, *args: Arg, **kwargs,) -> None:
        super().__init__(ty, **kwargs)
        self.args = Node.join(args)

        if len(args) != 0: self.args.parent = (self, 'args')

    def children(self) -> Iterable[Node]:
        return self.args.iterate()

    def tokenize(self, _: CodeGenerator) -> Iterable[str | CodeCC]:
        return self.emit_comment_tokens(inline=True) + \
            [f'new {self.type}(' + ', '.join(str(arg) for arg in self.args.iterate()) + ')']

class NewArray(Expr):
    def __init__(self, ty: Type, count: int, **kwargs,) -> None:
        super().__init__(ty, **kwargs)
        self.count = count

    def tokenize(self, _: CodeGenerator) -> Iterable[str | CodeCC]:
        return self.emit_comment_tokens(inline=True) + [f'new {self.type}[{self.count}]']

class Assign(Expr):
    def __init__(self, lhs: Expr, rhs: Expr, **kwargs):
        super().__init__(ty=lhs.type, **kwargs)

        self.lhs = lhs
        self.rhs = rhs

        lhs.parent = (self, 'lhs')
        rhs.parent = (self, 'rhs')

    def children(self) -> Iterable[Node]:
        return [self.lhs, self.rhs]

    def tokenize(self, cg: CodeGenerator) -> Iterable[str | CodeCC]:
        return chain(
            self.lhs.tokenize(cg),
            self.emit_comment_tokens(inline=True),
            [' = '],
            self.rhs.tokenize(cg)
        )

class This(Node):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)

    def tokenize(self, cg: CodeGenerator) -> Iterable[str | CodeCC]:
        return self.emit_comment_tokens(inline=True) + ['this']

class Return(Stmt):
    def __init__(self, expr: 'Expr | None' = None, **kwargs) -> None:
        super().__init__(**kwargs)
        self.expr = expr
        if expr is not None: self.expr.parent = (self, 'expr')

    def children(self) -> Iterable[Node]:
        return [self.expr] if self.expr is not None else []

    def tokenize(self, cg: CodeGenerator) -> Iterable[str | CodeCC]:
        tokens = self.emit_comment_tokens()
        if self.expr is not None:
            return chain(tokens, ['return '], self.expr.tokenize(cg), [';\n'])
        else:
            return tokens +  ['return;\n']

class Throw(Stmt):
    def __init__(self, expr: 'Expr', **kwargs) -> None:
        super().__init__(**kwargs)
        self.expr = expr;

    def children(self) -> Iterable[Node]:
        return [self.expr]

    def tokenize(self, cg: CodeGenerator) -> Iterable[str | CodeCC]:
        return chain(
            self.emit_comment_tokens(),
            ['throw '],
            self.expr.tokenize(cg), [';\n']
        )

class BinaryOp(Expr):
    def __init__(self, op: str, lhs: Expr, rhs: Expr, ty: Optional[Type] = None, **kwargs):
        if ty is None:
            super().__init__(ty=lhs.type, **kwargs)
        else:
            super().__init__(ty=ty, **kwargs)

        self.op = op
        self.lhs = lhs
        self.rhs = rhs

        self.lhs.parent = (self, 'lhs')
        self.rhs.parent = (self, 'rhs')

    def children(self) -> Iterable[Node]:
        return [self.lhs, self.rhs]

    def tokenize(self, cg: CodeGenerator) -> Iterable[str | CodeCC]:
        return chain(
            self.lhs.tokenize(cg),
            self.emit_comment_tokens(inline=True),
            [f' {self.op} '],
            self.rhs.tokenize(cg),
        )

class If(Stmt):
    def __init__(
        self,
        condition: Expr,
        then: Stmt,
        else_: Optional[Stmt] = None,
        **kwargs
    ) -> None:
        super().__init__(**kwargs)
        self.condition = condition
        self.then_ = then
        self.else_ = else_ if else_ is not None else NullNode()

        self.condition.parent = (self, 'condition')
        self.then_.parent = (self, 'then_')
        if else_ is not None: self.else_.parent = (self, 'else_')

    def children(self) -> Iterable[Node]:
        return chain(
            [self.condition],
            self.then_.iterate(),
            self.else_.iterate()
        )

    def tokenize(self, cg: CodeGenerator) -> Iterable[str | CodeCC]:
        tokens = chain(
            ['if('], self.condition.tokenize(cg), [')\n{\n', CodeCC.NEST],
            *(stmt.tokenize(cg) for stmt in self.then_.iterate()),
            [CodeCC.UNNEST, '}\n']
        )

        if not self.else_.null:
            tokens = chain(
                self.emit_comment_tokens(),
                tokens,
                ['else\n{\n', CodeCC.NEST],
                *(stmt.tokenize(cg) for stmt in self.else_.iterate()),
                [CodeCC.UNNEST, '}\n']
            )

        return tokens

class Cast(Expr):
    def __init__(self, ty: Type, expr: Expr, **kwargs):
        super().__init__(ty, **kwargs)
        self.expr = expr

        self.expr.parent = (self, 'expr')

    def children(self) -> Iterable[Node]:
        return [self.expr]

    def tokenize(self, cg: CodeGenerator) -> Iterable[str | CodeCC]:
        return chain(
            self.emit_comment_tokens(inline=True),
            [f'({str(self.type)})'],
            self.expr.tokenize(cg)
        )
