//
//  Instantiator.m
//  Hernix
//
//  Created by Timothy Larkin on 2/23/07.
//  Copyright 2007 Abstract Tools. All rights reserved.
//

#import "Instantiator.h"
#import "HMTVDD.h"
#import "HMPart.h"
#import "HMLevel.h"
#import "HMOutput.h"
#import "HMHTL.h"

NSArray *globals;
HMOutput *gTime;

HMLevel *partsFromDictionaries(NSArray *dictionaries)
{
	gTime = [[HMOutput alloc] init];
	[gTime setName:@"[time]"];
	NSMutableArray *globs = [NSMutableArray array];
	[globs addObject:gTime];
	HMLevel *root = nil;
	NSMutableDictionary *parts = [NSMutableDictionary dictionary];
	NSEnumerator *e = [dictionaries objectEnumerator];
	NSDictionary *partDict;
	NSBundle *bundle = [NSBundle mainBundle];
	NSDictionary *tmp;
	NSArray *classes = [NSArray arrayWithObjects:@"HMExpression", @"HMTVDD", @"HM2DTVDD", @"HMHTL", 
		@"HMLevel", @"HMInput", @"HMOutput", @"HMLookup", @"HMFile", @"HMInputSplitter",
                        @"HMWeather", nil];
	while (partDict = [e nextObject]) {
		NSString *ucclassname = [partDict valueForKey:@"class"], *class;
		if ([ucclassname isEqualToString:@"HMTEMPLATE"]) {
			continue;
		}
		NSEnumerator *f = [classes objectEnumerator];
		while (class = [f nextObject]) {
			if ([[class uppercaseString] isEqualToString:ucclassname]) {
				break;
			}
		}
		NSCAssert1(class, @"Couldn't find class for %@", ucclassname);
		HMNode *part = [[[bundle classNamed:class] alloc] init];
		NSString *nodeID = [partDict valueForKey:@"id"];
		[part setNodeID:nodeID];
		f = [[partDict valueForKey:@"attributes"] objectEnumerator];
		while (tmp = [f nextObject]) {
            NSString *type = [tmp valueForKey:@"type"];
            if ([type isEqualToString:@"encodable"]) {
                NSData *archive = [[NSData alloc] initWithBase64EncodedString:[tmp valueForKey:@"value"]
                                                                   options:NSDataBase64DecodingIgnoreUnknownCharacters];
                NSArray *data = [NSKeyedUnarchiver unarchiveObjectWithData:archive];
                [part setValue:data forKey:@"data"];
                
            } else {
                [part setValue:[tmp valueForKey:@"value"] forKey:[tmp valueForKey:@"name"]];                
            }
		}
		if ([class isEqualToString:@"HMOutput"] && isGlobal([part name])) {
			[globs addObject:part];
			[HMHTL addSharedVariable:[part name] withValue:(Value*)[(HMOutput*)part value]];
		}
		[parts setValue:[NSDictionary dictionaryWithObjectsAndKeys:part, @"part",
			[partDict valueForKey:@"relationships"], @"relations", nil]
				 forKey:nodeID];
	}
	globals = [NSArray arrayWithArray:globs];
	[globals retain];
	e = [[parts allValues] objectEnumerator];
	NSMutableArray *allObjects = [NSMutableArray array];
	while (tmp = [e nextObject]) {
		HMNode *part = [tmp valueForKey:@"part"];
		NSEnumerator *f = [[tmp valueForKey:@"relations"] objectEnumerator];
		NSDictionary *tmp2;
		while (tmp2 = [f nextObject]) {
			NSString *key = [tmp2 valueForKey:@"name"];
			NSEnumerator *g = [[tmp2 valueForKey:@"targets"] objectEnumerator];
			NSString *target;
			NSMutableArray *array = [NSMutableArray array];
			NSString *type = [tmp2 valueForKey:@"type"];
			if ([type isEqualToString:@"1/1"]) {
				target = [g nextObject];
				if (target) {
					HMNode *t = [[parts valueForKey:target] valueForKey:@"part"];
					NSCAssert1(t != nil, @"No match for key \"part\" for node %@", target);
					[part setValue:t forKey:key];
				}
			}
			else {
				while (target = [g nextObject]) {
					HMNode *t = [[parts valueForKey:target] valueForKey:@"part"];
					if (t == nil) {
						NSLog(@"No match for key");
					}
					else {
						[array addObject:t];
					}
				}
				[part setValue:array forKey:key];
			}
		}
		if ([part isKindOfClass:[HMPart class]]) {
			[allObjects addObject:part];
			NSSortDescriptor *sd = [[NSSortDescriptor alloc] initWithKey:@"varid" ascending:YES];
			NSArray *tmp = [(HMPart*)part inputs];
			tmp = [tmp sortedArrayUsingDescriptors:[NSArray arrayWithObject:sd]];
			[(HMPart*)part setInputs:tmp];
			tmp = [(HMPart*)part outputs];
			tmp = [tmp sortedArrayUsingDescriptors:[NSArray arrayWithObject:sd]];
			[(HMPart*)part setOutputs:tmp];
			[sd release];
			
		}
	}
	e = [allObjects objectEnumerator];
	HMPart *part;
	while(part = [e nextObject]) {
		if ([part parent] == nil) {
			root = (HMLevel*)part;
			[allObjects removeObject:root];
			[root setFlattened:allObjects];
			break;
		}
	}
	NSCAssert(root, @"Failure to produce root of model");
	return root;
}

#if __APPLE__

NSArray *XMLtoDictionaries(NSString *path)
{
	NSError *error;
	NSXMLDocument *doc = [[NSXMLDocument alloc] initWithContentsOfURL:[NSURL fileURLWithPath:path]
															  options:0 
																error:&error];
	if (error) {
		NSLog(@"Error opening XML document %@", path);
		return nil;
	}
	NSArray *objects = [doc objectsForXQuery:@"database/object" error:&error];
	// Clang suggests
	[doc release];
	NSEnumerator *e = [objects objectEnumerator];
	NSXMLElement *element;
	NSMutableArray *model = [NSMutableArray array];
	while (element = [e nextObject]) {
		NSMutableDictionary *object = [NSMutableDictionary dictionary];
		NSXMLNode *s = [element attributeForName:@"type"];
		[object setValue:[s stringValue] forKey:@"class"];
		s = [element attributeForName:@"id"];
		[object setValue:[s stringValue] forKey:@"id"];
		NSArray *attributes = [element elementsForName:@"attribute"];
		NSMutableArray *parsedAttributes = [NSMutableArray array];
		[object setValue:parsedAttributes forKey:@"attributes"];
		NSEnumerator *f = [attributes objectEnumerator];
		NSXMLElement *prop;
		while (prop = [f nextObject]) {
			NSMutableDictionary *d = [NSMutableDictionary dictionary];
			NSEnumerator *g = [[prop attributes] objectEnumerator];
			NSXMLNode *node;
			while (node = [g nextObject]) {
				[d setValue:[node stringValue] forKey:[node name]];
			}
			[d setValue:[prop stringValue] forKey:@"value"];
			[parsedAttributes addObject:d];
		}
		
		NSArray *relationships = [element elementsForName:@"relationship"];
		f = [relationships objectEnumerator];
		NSMutableArray *array = [NSMutableArray array];
		while (prop = [f nextObject]) {
			NSMutableDictionary *d = [NSMutableDictionary dictionary];
			[d setValue:[[prop attributeForName:@"name"] stringValue] forKey:@"name"];
			[d setValue:[[prop attributeForName:@"type"] stringValue] forKey:@"type"];
			s = [prop attributeForName:@"idrefs"];
			NSString *idrefs = [s stringValue];
			NSArray *refs = [idrefs componentsSeparatedByString:@" "];
			[d setValue:refs forKey:@"targets"];
			[array addObject:d];
		}
		[object setValue:array forKey:@"relationships"];
		[model addObject:object];
	}
	
	return model;
}

#endif

#if __linux__

#import <GNUstepBase/GSXML.h>

NSArray *XMLtoDictionaries(NSString *path)
{
  //	NSError *error;
	GSXMLParser *parser = [GSXMLParser parserWithContentsOfFile:path];
	BOOL parsed;
	parsed = [parser parse];
	if (!parsed) {
		NSLog(@"Error opening XML document %@", path);
		return nil;
	}
	GSXMLDocument *d = [parser document];
	GSXMLNode *root = [d root];
	GSXPathContext *c = [[GSXPathContext alloc] initWithDocument:d];
	GSXMLNode *element = [root firstChildElement];
	element = [element nextElement];
	NSMutableArray *model = [NSMutableArray array];
	int i = 1;
	while(element) {
		NSMutableDictionary *object = [NSMutableDictionary dictionary];
		//NSDictionary *attributes = [element attributes];
		NSString *s = [element objectForKey:@"type"];
		[object setValue:s forKey:@"class"];
		s = [element objectForKey:@"id"];
		[object setValue:s forKey:@"id"];
		NSString *exp = [NSString stringWithFormat:@"object[%d]/attribute", i];
		GSXPathNodeSet *attributes = (GSXPathNodeSet *)[c   evaluateExpression:exp];
		NSMutableArray *parsedAttributes = [NSMutableArray array];
		[object setValue:parsedAttributes forKey:@"attributes"];
		int j;
		GSXMLNode *prop;
		for(j = 0; j < [attributes count]; j++) {
			GSXMLNode *node = [attributes nodeAtIndex:j];
			NSMutableDictionary *d = [NSMutableDictionary dictionary];
			NSDictionary *attributes = [node attributes];
			NSEnumerator *g = [[attributes allKeys] objectEnumerator];
			NSString *key;
			while (key = [g nextObject]) {
				[d setValue:[attributes valueForKey:key] forKey:key];
			}
			[d setValue:[node content] forKey:@"value"];
			[parsedAttributes addObject:d];
		}
		
		exp = [NSString stringWithFormat:@"object[%d]/relationship", i];	
		GSXPathNodeSet *relationships = (GSXPathNodeSet *)[c evaluateExpression:exp];
		NSMutableArray *array = [NSMutableArray array];
		for(j = 0; j < [relationships count]; j++) {
			prop = [relationships nodeAtIndex:j];
			NSMutableDictionary *d = [NSMutableDictionary dictionary];
			[d setValue:[prop objectForKey:@"name"] forKey:@"name"];
			[d setValue:[prop objectForKey:@"type"] forKey:@"type"];
			s = [prop objectForKey:@"idrefs"];
			NSString *idrefs = s;
			NSArray *refs = [idrefs componentsSeparatedByString:@" "];
			[d setValue:refs forKey:@"targets"];
			[array addObject:d];
		}
		[object setValue:array forKey:@"relationships"];
		[model addObject:object];
		element = [element nextElement];
		i++;
	}
	return model;
}

#endif

NSArray *buildMatrix(NSArray *dictionaries, int nRows, int nColumns)
{
	NSMutableArray *rows = [NSMutableArray array];
	int i, j;
	for (i = 0; i < nRows; i++) {
		NSMutableArray *columns = [NSMutableArray array];
		for (j = 0;  j < nColumns; j++) {
			HMLevel *model = partsFromDictionaries(dictionaries);
			[columns addObject:model];
		}
		[rows addObject:columns];
	}
	return rows;
}

Direction opposite(Direction d)
{
	switch (d) {
		case north: return south;
		case south:  return north;
		case east: return west;
		case west: return east;
        	case nDirections: return -1;
	}
	return -1;
}

BOOL neighbor(unsigned int x, unsigned int y,
			  unsigned int maxX, unsigned int maxY,
			  Direction d,
			  unsigned int *xNeighbor, unsigned int *yNeighbor)
{
	switch (d) {
		case north: 
			y++;
			break;
		case south:
			y--;
			break;
		case east:
			x++;
			break;
		case west:
			x--;
			break;
	case nDirections: break;
	}
	
	if (//(x < 0) || (y < 0) ||
        (x >= maxX) || (y >= maxY)) {
		return NO;
	}
	*yNeighbor = y;
	*xNeighbor = x;
	return YES;
}


void wireMatrix(NSArray *matrix)
{
	int iRow = 0, iCol;
	Direction direction;
	int nRows = [matrix count];
	int nCols = [[matrix objectAtIndex:0] count];
	NSEnumerator *e = [matrix objectEnumerator], *f, *g;
	NSArray *row;
	HMLevel *model;
	NSMutableIndexSet *edges;
	while (row = [e nextObject]) {
		f = [row objectEnumerator];
		iCol = 0;
		while(model = [f nextObject]) {
			g = [[model flattened] objectEnumerator];
			HMTVDD *part;
			while (part = [g nextObject]) {
				if ([part isMemberOfClass:[HMTVDD class]]) {
					[part setPosition:NSMakePoint(iCol, iRow)];
					edges = [NSMutableIndexSet indexSet];
					NSString *nodeID = [part nodeID];
					unsigned int yNeighbor, xNeighbor;
					HMTVDD *twin;
					for (direction = north; direction < nDirections; direction++) {
						if (neighbor(iCol, iRow, nCols, nRows, 
									 direction, &xNeighbor, &yNeighbor)) {
							[edges addIndex:direction];
							model = [[matrix objectAtIndex:yNeighbor] objectAtIndex:xNeighbor];
							twin = (HMTVDD*)[model partWithNodeID:nodeID];
							[twin setImigration:[part emigrationInDirection:direction]
								  fromDirection:opposite(direction)];
						}
					}
					[part setEdges:edges];
				}
			}
			iCol++;
		}
		iRow++;
	}
}


