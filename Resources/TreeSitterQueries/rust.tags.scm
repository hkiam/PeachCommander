; ADT definitions

(struct_item
    name: (type_identifier) @name) @definition.class

(enum_item
    name: (type_identifier) @name) @definition.class

(union_item
    name: (type_identifier) @name) @definition.class

; type aliases

(type_item
    name: (type_identifier) @name) @definition.class

; method definitions

(declaration_list
    (function_item
        name: (identifier) @name) @definition.method)

; function definitions

(function_item
    name: (identifier) @name) @definition.function

; trait definitions
(trait_item
    name: (type_identifier) @name) @definition.interface

; module definitions
(mod_item
    name: (identifier) @name) @definition.module

; macro definitions

(macro_definition
    name: (identifier) @name) @definition.macro

; references

(call_expression
    function: (identifier) @name) @reference.call

(call_expression
    function: (field_expression
        field: (field_identifier) @name)) @reference.call

(macro_invocation
    macro: (identifier) @name) @reference.call

; implementations

(impl_item
    trait: (type_identifier) @name) @reference.implementation

(impl_item
    type: (type_identifier) @name
    !trait) @reference.implementation

; impl blocks — captured so their methods nest under the implemented type
; (merged with the type's struct/enum definition of the same name).
(impl_item
    type: (type_identifier) @name) @definition.class

; generic impl blocks — impl<T> Foo<T> { … } / impl … for Foo<T> { … }
; (here the type is a generic_type, not a bare type_identifier).
(impl_item
    type: (generic_type
        type: (type_identifier) @name)) @definition.class

; trait method signatures without a body — fn foo(&self) -> T;
; (bodied methods are function_item, matched above; signatures are a distinct node).
(declaration_list
    (function_signature_item
        name: (identifier) @name) @definition.method)
