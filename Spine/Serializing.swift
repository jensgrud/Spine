//
//  Mapping.swift
//  Spine
//
//  Created by Ward van Teijlingen on 23-08-14.
//  Copyright (c) 2014 Ward van Teijlingen. All rights reserved.
//

import UIKit
import SwiftyJSON

typealias DeserializationResult = (store: Store?, pagination: PaginationData?, error: NSError?)

// MARK: - Serializer

protocol SerializerProtocol {
	// Class mapping
	func registerClass(type: Resource.Type)
	func unregisterClass(type: Resource.Type)
	func classNameForResourceType(resourceType: String) -> Resource.Type
	
	// Deserializing
	func deserializeData(data: NSData, options: DeserializationOptions) -> DeserializationResult
	func deserializeData(data: NSData, usingStore store: Store, options: DeserializationOptions) -> DeserializationResult
	func deserializeError(data: NSData, withResonseStatus responseStatus: Int) -> NSError
	
	// Serializing
	func serializeResources(resources: [Resource], options: SerializationOptions) -> [String: AnyObject]
}

/**
*  The serializer is responsible for serializing and deserialing resources.
*  It stores information about the Resource classes using a ResourceClassMap
*  and uses SerializationOperations and DeserialisationOperations for (de)serializing.
*/
class JSONAPISerializer: SerializerProtocol {
	
	/// The class map that holds information about resource type/class mapping.
	private var classMap: ResourceClassMap = ResourceClassMap()
	
	
	//MARK: Class mapping
	
	/**
	Register a Resource subclass with this serializer.
	Example: `classMap.register(User.self)`
	
	:param: type The Type of the subclass to register.
	*/
	func registerClass(type: Resource.Type) {
		self.classMap.registerClass(type)
	}
	
	/**
	Unregister a Resource subclass from this serializer. If the type was not prevously registered, nothing happens.
	Example: `classMap.unregister(User.self)`
	
	:param: type The Type of the subclass to unregister.
	*/
	func unregisterClass(type: Resource.Type) {
		self.classMap.unregisterClass(type)
	}
	
	/**
	Returns the Resource.Type into which a resource with the given type should be mapped.
	
	:param: resourceType The resource type for which to return the matching class.
	
	:returns: The Resource.Type that matches the given resource type.
	*/
	func classNameForResourceType(resourceType: String) -> Resource.Type {
		return self.classMap[resourceType]
	}
	
	
	// MARK: Serializing
	
	/**
	Deserializes the given data into a SerializationResult. This is a thin wrapper around
	a DeserializeOperation that does the actual deserialization.
	
	:param: data The data to deserialize.
	
	:returns: A DeserializationResult that contains either a Store or an error.
	*/
	func deserializeData(data: NSData, options: DeserializationOptions = DeserializationOptions()) -> DeserializationResult {
		let mappingOperation = DeserializeOperation(data: data, classMap: self.classMap, options: options)
		mappingOperation.start()
		return mappingOperation.result!
	}
	
	/**
	Deserializes the given data into a SerializationResult. This is a thin wrapper around
	a DeserializeOperation that does the actual deserialization.
	
	Use this method if you want to deserialize onto existing Resource instances. Otherwise, use
	the regular `deserializeData` method.
	
	:param: data  The data to deserialize.
	:param: store A Store that contains Resource instances onto which data will be deserialize.
	
	:returns: A DeserializationResult that contains either a Store or an error.
	*/
	
	func deserializeData(data: NSData, usingStore store: Store, options: DeserializationOptions = DeserializationOptions()) -> DeserializationResult {
		let mappingOperation = DeserializeOperation(data: data, store: store, classMap: self.classMap, options: options)
		mappingOperation.start()
		return mappingOperation.result!
	}
	
	
	/**
	Deserializes the given data into an NSError. Use this method if the server response is not in the
	200 successful range.
	
	The error returned will contain the error code specified in the `error` section of the response.
	If no error code is available, the given HTTP response status code will be used instead.
	If the `error` section contains a `title` key, it's value will be used for the NSLocalizedDescriptionKey.
	
	:param: data           The data to deserialize.
	:param: responseStatus The HTTP response status which will be used when an error code is absent in the data.
	
	:returns: A NSError deserialized from the given data.
	*/
	func deserializeError(data: NSData, withResonseStatus responseStatus: Int) -> NSError {
		let json = JSON(data as NSData!)
		
		let code = json["errors"][0]["id"].int ?? responseStatus
		
		var userInfo: [String : AnyObject]?
		
		if let errorTitle = json["errors"][0]["title"].string {
			userInfo = [NSLocalizedDescriptionKey: errorTitle]
		}
		
		return NSError(domain: SPINE_API_ERROR_DOMAIN, code: code, userInfo: userInfo)
	}
	
	/**
	Serializes the given Resources into a multidimensional dictionary/array structure
	that can be passed to NSJSONSerialization.
	
	:param: resources The resources to serialize.
	:param: mode      The serialization mode to use.
	
	:returns: A multidimensional dictionary/array structure.
	*/
	func serializeResources(resources: [Resource], options: SerializationOptions = SerializationOptions()) -> [String: AnyObject] {
		let mappingOperation = SerializeOperation(resources: resources, options: options)
		mappingOperation.start()
		return mappingOperation.result!
	}
}


// MARK: - Options

struct SerializationOptions {
	var dirtyAttributesOnly = true
	var includeToMany = false
	var includeToOne = false
	
	init(dirtyAttributesOnly: Bool = false, includeToMany: Bool = false, includeToOne: Bool = false) {
		self.dirtyAttributesOnly = dirtyAttributesOnly
		self.includeToMany = includeToMany
		self.includeToOne = includeToOne
	}
}

struct DeserializationOptions {
	var mapOntoFirstResourceInStore = false
	
	init(mapOntoFirstResourceInStore: Bool = false) {
		self.mapOntoFirstResourceInStore = mapOntoFirstResourceInStore
	}
}


// MARK: - Class map

/**
*  A ResourceClassMap contains information about how resource types
*  should be mapped to Resource classes.

*  Each resource type is mapped to one specific Resource subclass.
*/
struct ResourceClassMap {
	
	/// The registered resource type/class pairs.
	private var registeredClasses: [String: Resource.Type] = [:]
	
	/**
	Register a Resource subclass.
	Example: `classMap.register(User.self)`
	
	:param: type The Type of the subclass to register.
	*/
	mutating func registerClass(type: Resource.Type) {
		let typeString = type().type
		assert(registeredClasses[typeString] == nil, "Cannot register class of type \(type). A class with that type is already registered.")
		self.registeredClasses[typeString] = type
	}
	
	/**
	Unregister a Resource subclass. If the type was not prevously registered, nothing happens.
	Example: `classMap.unregister(User.self)`
	
	:param: type The Type of the subclass to unregister.
	*/
	mutating func unregisterClass(type: Resource.Type) {
		let typeString = type().type
		assert(registeredClasses[typeString] != nil, "Cannot unregister class of type \(type). Type does not exist in the class map.")
		self.registeredClasses[typeString] = nil
	}
	
	/**
	Returns the Resource.Type into which a resource with the given type should be mapped.
	
	:param: resourceType The resource type for which to return the matching class.
	
	:returns: The Resource.Type that matches the given resource type.
	*/
	func classForResourceType(type: String) -> Resource.Type {
		assert(registeredClasses[type] != nil, "Cannot map resources of type \(type). You must create a Resource subclass and register it with Spine.")
		return registeredClasses[type]!
	}
	
	/**
	*  Returns the Resource.Type into which a resource with the given type should be mapped.
	*/
	subscript(type: String) -> Resource.Type {
		return self.classForResourceType(type)
	}
}